require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Fragment::Exercise, vcr: VCR_OPTS do
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
  let(:exercise_fragments) { fragments.select { |f| f.instance_of? described_class } }

  let(:expected_queries)   do
    [[]]
  end

  it 'provides info about the exercise fragment' do
    exercise_fragments.each_with_index do |fragment, index|
      expect(fragment.title).to be_nil
      expect(fragment.embed_queries).to eq expected_queries[index]
    end
  end

  it 'can absolutize exercise tag urls' do
    absolutized_node = described_class.absolutize_exercise_urls!(
      Nokogiri::HTML.fragment(
        "<div class=\"exercise\">
           <a href=\"#ost/api/ex/some-tag\">[Link]</a>
         </div>"
      )
    ).at_css('a')
    expected_url = OpenStax::Exercises::V1.uri_for('/api/exercises').tap do |uri|
      uri.query_values = { q: 'tag:"some-tag"' }
    end.to_s

    expect(absolutized_node['href']).to eq expected_url
    expect(absolutized_node['data-type']).to eq 'exercise'
  end

  it 'can absolutize exercise nickname urls' do
    absolutized_node = described_class.absolutize_exercise_urls!(
      Nokogiri::HTML.fragment(
        "<div class=\"exercise\">
           <a href=\"#exercise/Some Nickname\">[Link]</a>
         </div>"
      )
    ).at_css('a')
    expected_url = OpenStax::Exercises::V1.uri_for('/api/exercises').tap do |uri|
      uri.query_values = { q: 'nickname:"Some Nickname"' }
    end.to_s

    expect(absolutized_node['href']).to eq expected_url
    expect(absolutized_node['data-type']).to eq 'exercise'
  end
end
