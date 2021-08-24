require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::FragmentSplitter, vcr: VCR_OPTS do
  let(:reference_view_url) { 'https://www.example.com' }
  let(:fragment_splitter)  do
    described_class.new HS_PHYSICS_READING_PROCESSING_INSTRUCTIONS, reference_view_url
  end

  context 'html node operations' do
    let(:top)    { OpenStruct.new(parent: nil, remove: nil, children: [], content: 'stop') }
    let(:parent) { OpenStruct.new(parent: top, remove: nil, children: [], content: '') }
    let(:left)   { OpenStruct.new(parent: parent, remove: nil, content: 'left') }
    let(:right)  { OpenStruct.new(parent: parent, remove: nil, content: 'right') }
    let(:node)   { OpenStruct.new(parent: parent, remove: nil, content: 'node') }

    context '#recursive_compact' do
      it 'stops at the indicated stop_node' do
        expect(fragment_splitter.send :recursive_compact, node, node).to be_nil
      end

      it 'removes the passed in node' do
        allow(node).to receive(:remove)
        fragment_splitter.send :recursive_compact, node, top
        expect(node).to have_received(:remove)
      end

      it 'removes empty parents recursively' do
        allow(parent).to receive(:remove)
        fragment_splitter.send :recursive_compact, node, top
        expect(parent).to have_received(:remove)
      end
    end

    context '#remove_before' do
      it 'stops at the indicated stop_node' do
        expect(fragment_splitter.send :remove_before, node, node).to be_nil
      end

      it 'removes siblings before the node recursively' do
        top.children = [parent]
        parent.children = [left, node, right]

        fragment_splitter.send :remove_before, node, top

        expect(parent.children).to eq([node, right])
      end
    end

    context '#remove_after' do
      it 'stops at the indicated stop_node' do
        expect(fragment_splitter.send :remove_after, node, node).to be_nil
      end

      it 'removes siblings after the node recursively' do
        top.children = [parent]
        parent.children = [left, node, right]

        fragment_splitter.send :remove_after, node, top

        expect(parent.children).to eq([left, node])
      end
    end
  end

  context 'with page' do
    before(:all) do
      @page_fragment_infos = [
        {
          id: MINI_BOOK_PAGE_HASHES[0]['id'],
          fragments: %w{Reading Video Exercise},
          worked_examples: %w{Reading}
        },
        {
          id: MINI_BOOK_PAGE_HASHES[1]['id'],
          fragments: %w{Reading Reading Reading Video Exercise Reading Reading},
          worked_examples: %w{Reading}
        },
        {
          id: MINI_BOOK_PAGE_HASHES[2]['id'],
          fragments: %w{Reading Video Exercise Reading Reading Interactive Exercise},
          worked_examples: %w{Reading}
        },
        {
          id: MINI_BOOK_PAGE_HASHES[3]['id'],
          fragments: %w{Reading Reading Reading Reading Reading Reading Interactive Exercise},
          worked_examples: %w{Reading}
        },
        {
          id: MINI_BOOK_PAGE_HASHES[4]['id'],
          fragments: %w{Reading},
          worked_examples: %w{Reading}
        },
      ]

      VCR.use_cassette('OpenStax_Content_FragmentSplitter/with_pages', VCR_OPTS) do
        @page_fragment_infos.each do |hash|
          hash[:fragments].map! { |fg| OpenStax::Content::Fragment.const_get fg }
          hash[:worked_examples].map! { |fg| OpenStax::Content::Fragment.const_get fg }
          hash[:page] = OpenStax::Content::Page.new(
            book: MINI_BOOK, uuid: hash[:id]
          ).tap(&:convert_content!)
        end
      end
    end

    it 'splits the given pages into the expected fragments for HS' do
      fragment_splitter = described_class.new(
        HS_PHYSICS_READING_PROCESSING_INSTRUCTIONS, reference_view_url
      )
      @page_fragment_infos.each do |hash|
        fragments = fragment_splitter.split_into_fragments(hash[:page].root)
        expect(fragments.map(&:class)).to eq hash[:fragments]
      end
    end

    it 'does not split reading steps before a worked example' do
      worked_example_processing_instructions = [
        { css: '.ost-reading-discard, .os-teacher, [data-type="glossary"]',
          fragments: [], except: 'snap-lab' },
        { css: '.worked-example', fragments: ['node', 'optional_exercise'] }
      ]
      fragment_splitter = described_class.new(
        worked_example_processing_instructions, reference_view_url
      )

      hash = @page_fragment_infos.first
      fragments = fragment_splitter.split_into_fragments(hash[:page].root)
      expect(fragments.map(&:class)).to eq hash[:worked_examples]

      fragments.each_slice(2).each do |reading_fragment, optional_exercise_fragment|
        next if optional_exercise_fragment.nil? # Last fragment - not a worked example

        # The worked example node is included in the reading fragment before it
        node = Nokogiri::HTML.fragment(reading_fragment.to_html)
        expect(node.at_css('.worked-example')).to be_present
      end
    end
  end

  context 'excluded content' do
    let(:reading_processing_instructions) do
      [
        {
          css: '.section-summary, .key-terms, .review-questions, .discussion-questions,' +
               '.case-questions, .suggested-resources, .references, .figure-credits',
          fragments: []
        }
      ]
    end
    let(:excluded_content) do
      <<~EOS
        <div class=\"os-eoc os-section-summary-container\" data-type=\"composite-page\" data-uuid-key=\".section-summary\" id=\"composite-page-2\"><h2 data-type=\"document-title\"><span class=\"os-text\">Summary</span></h2><section data-depth=\"1\" id=\"fs-idm326738544\" class=\"section-summary\"><a href=\"./d380510e-6145-4625-b19a-4fa68204b6b1@12.7:d51e5dbd-ff69-4828-a882-9c6e8a940365.xhtml#0\" data-page-slug=\"1-1-entrepreneurship-today\" data-page-uuid=\"d51e5dbd-ff69-4828-a882-9c6e8a940365\" data-page-fragment=\"0\"><h3 data-type=\"document-title\" id=\"0_copy_1\"><span class=\"os-number\">1.1</span><span class=\"os-divider\"> </span><span data-type=\"\" itemprop=\"\" class=\"os-text\">Entrepreneurship Today</span></h3></a>\n<p id=\"fs-idm343555472\" class=\" \">An entrepreneur is someone who takes on an entrepreneurial venture to create something new that solves a problem; small business ownership and franchising are also entrepreneurial options. The venture could be for profit or not for profit, depending on the problem it intends to solve. Entrepreneurs can remain in a full-time job while pursuing their ideas on the side, in order to mitigate risk. On the opposite end of the spectrum, entrepreneurs can take on lifestyle ventures and become serial entrepreneurs. There are many factors driving the growth of entrepreneurship, including employment instability, motivation to create something new, financial factors and free time associated with retirement, and the greater acceptance of entrepreneurship as a career choice. The cultures of nations around the world affect the ability for entrepreneurs to start a venture, making the United States a leader in entrepreneurial innovation. Entrepreneurs often find inspiration in social, environmental, and economic issues.</p>\n</section><section data-depth=\"1\" id=\"fs-idm351936432\" class=\"section-summary\"><a href=\"./d380510e-6145-4625-b19a-4fa68204b6b1@12.7:7ccc54a5-2430-429f-b74e-c94732f87418.xhtml#0\" data-page-slug=\"1-2-entrepreneurial-vision-and-goals\" data-page-uuid=\"7ccc54a5-2430-429f-b74e-c94732f87418\" data-page-fragment=\"0\"><h3 data-type=\"document-title\" id=\"0_copy_10\"><span class=\"os-number\">1.2</span><span class=\"os-divider\"> </span><span data-type=\"\" itemprop=\"\" class=\"os-text\">Entrepreneurial Vision and Goals</span></h3></a>\n<p id=\"fs-idm327774096\" class=\" \">Establishing an entrepreneurial vision helps you describe what you want your venture to become in the future. For most entrepreneurial ventures, the vision also includes the harvesting or selling of the venture. There are creative ways, such as brainstorming and divergent thinking, as well as investigative ways to define an entrepreneurial vision. Once you have established your vision, it is important to write goals to help you realize the steps toward making your vision a reality.</p>\n</section><section data-depth=\"1\" id=\"fs-idm400249200\" class=\"section-summary\"><a href=\"./d380510e-6145-4625-b19a-4fa68204b6b1@12.7:eca9a0ef-7ef7-47d3-abaf-ce21ce92452d.xhtml#0\" data-page-slug=\"1-3-the-entrepreneurial-mindset\" data-page-uuid=\"eca9a0ef-7ef7-47d3-abaf-ce21ce92452d\" data-page-fragment=\"0\"><h3 data-type=\"document-title\" id=\"0_copy_11\"><span class=\"os-number\">1.3</span><span class=\"os-divider\"> </span><span data-type=\"\" itemprop=\"\" class=\"os-text\">The Entrepreneurial Mindset</span></h3></a>\n<p id=\"fs-idm368257280\" class=\" \">Identifying new possibilities, solving problems, and improving the quality of life on our planet are all important aspects of entrepreneurship. The entrepreneurial mindset allows an entrepreneur to view the world as full of possibilities. Entrepreneurial passion and spirit help entrepreneurs overcome obstacles to achieve their goals. Disruptive technologies involve using existing technology in new ways and can provide new opportunities as well as new challenges. Entrepreneurship is transforming some industries and potentially creating others, though many entrepreneurs create value by starting small businesses, buying franchises, or introducing new services in mature industries. The key thing to remember is that anyone can be an entrepreneur and that new technologies are making the cost of starting a new business less costly, but still risky at some level.</p>\n</section></div>
      EOS
    end
    let(:node) { Nokogiri::HTML.fragment excluded_content }

    it 'produces no fragments if reading processing instructions exclude all non-title content' do
      fragment_splitter = described_class.new reading_processing_instructions, reference_view_url
      expect(fragment_splitter.split_into_fragments(node)).to eq []
    end
  end
end
