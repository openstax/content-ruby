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
end
