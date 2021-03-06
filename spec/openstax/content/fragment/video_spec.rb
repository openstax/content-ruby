require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Fragment::Video, vcr: VCR_OPTS do
  let(:reference_view_url) { 'https://www.example.com' }
  let(:fragment_splitter)  do
    OpenStax::Content::FragmentSplitter.new(
      HS_PHYSICS_READING_PROCESSING_INSTRUCTIONS, reference_view_url
    )
  end
  let(:page_uuid)          { MINI_BOOK_PAGE_HASHES.first['id'] }
  let(:page)               do
    OpenStax::Content::Page.new(book: MINI_BOOK, uuid: page_uuid).tap(&:convert_content!)
  end
  let(:fragments)          { fragment_splitter.split_into_fragments(page.root) }
  let(:video_fragments)    { fragments.select { |f| f.instance_of? described_class } }

  let(:expected_title)     { "Watch Physics: Newton’s First Law of Motion" }
  let(:expected_url)       { 'https://www.openstaxcollege.org/l/02newlawone' }
  let(:expected_content)   do
    <<~EOF
  <div data-type="note" data-has-label="true" id="fs-id1169085651531" class="watch-physics" data-label="" data-tutor-transform="true">
  <div data-type="title" id="5">Watch Physics: Newton’s First Law of Motion</div>



  <div data-type="content">
  <p id="fs-id1169085756824" class=" ">This video introduces and explains Newton’s first law of motion.</p>
  <div data-type="media" id="fs-id1169086146737" data-alt="This tutorial explains Newton’s first law of motion.">
  <div data-type="alternatives" class="os-has-iframe os-has-link">
  <a class="os-is-link" target="_window" href="https://www.openstaxcollege.org/l/02newlawone">Click to view content</a><iframe width="660" height="371.4" src="https://www.openstaxcollege.org/l/02newlawone" class="os-is-iframe os-embed video" title="Video"><!-- no-selfclose --></iframe>
  </div>
  </div>
  </div>
  </div>
    EOF
  end

  it 'provides info about the video fragment' do
    video_fragments.each do |fragment|
      expect(fragment.title).to eq expected_title
      content_lines = fragment.to_html.split("\n").map(&:strip)
      expected_content_lines = expected_content.split("\n").map(&:strip)
      expect(content_lines).to eq expected_content_lines
      expect(fragment.url).to eq expected_url
    end
  end
end
