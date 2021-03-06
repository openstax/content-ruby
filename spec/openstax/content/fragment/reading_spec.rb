require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Fragment::Reading, vcr: VCR_OPTS do
  let(:reference_view_url) { 'https://www.example.com' }
  let(:fragment_splitter)  do
    OpenStax::Content::FragmentSplitter.new(
      HS_PHYSICS_READING_PROCESSING_INSTRUCTIONS, reference_view_url
    )
  end
  let(:page_uuid)          { MINI_BOOK_PAGE_HASHES.first['id'] }
  let(:page)               { OpenStax::Content::Page.new(book: MINI_BOOK, uuid: page_uuid) }
  let(:fragments)          { fragment_splitter.split_into_fragments(page.root) }
  let(:reading_fragments)  { fragments.select { |f| f.instance_of? described_class } }

  it 'provides info about the reading fragment' do
    page.convert_content!

    reading_fragments.each do |fragment|
      expect(fragment.title).to be_nil
      expect(fragment.to_html).not_to be_empty
    end
  end

  it 'changes links to objects not found in this fragment to point to the reference view' do
    page.instance_variable_set :@content, <<~HTML
      <html>
        <body>
          <div id="content">
            <a href="#content">Content</a>

            <a href="#query">Query</a>
            <input name="query" type="text"/>

            <a href="#test">Test</a>

            <a href="#">Test random bad link</a>
          </div>
        </body>
      </html>
    HTML

    expect(reading_fragments.size).to eq 1
    reading_fragment = reading_fragments.first

    doc = Nokogiri::HTML.fragment(reading_fragment.to_html)
    body = doc.at_css('body')
    expect(body.at_css('[href="#"]')).not_to be_nil
    expect(body.at_css('[href="#content"]')).not_to be_nil
    expect(body.at_css('[href="#query"]')).not_to be_nil
    expect(body.at_css('[href="#test"]')).to be_nil
    expect(body.at_css("[href=\"#{reference_view_url}#test\"]")).not_to be_nil
  end

  it 'returns blank? == true for fragments containing only a title' do
    node = Nokogiri::HTML.fragment 'References'
    title_only_node = Nokogiri::HTML.fragment "<body><div class=\"os-eoc os-references-container\" data-type=\"composite-page\" data-uuid-key=\".references\" id=\"composite-page-6\">\n<h2 data-type=\"document-title\"><span class=\"os-text\">References</span></h2>\n\n</div></body>"

    expect(described_class.new node: node).not_to be_blank
    expect(described_class.new node: title_only_node).to be_blank
  end

  it 'does not write @node when serializing to yaml' do
    reading_fragments.each { |fragment| expect(fragment.to_yaml).not_to include('node: ') }
  end
end
