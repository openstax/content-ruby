require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Abl, vcr: VCR_OPTS do
  subject(:abl) { described_class.new }
  let(:books)   { abl.books }

  it 'can generate a list of approved books from the ABL' do
    expect(books).not_to be_empty

    books.each { |book| expect(book).to be_a(OpenStax::Content::Book) }
  end

  it "can return the ABL's digest" do
    expect(abl.digest).to eq '1af6dd1b7c006c91563d3a07598bc2a117b53ae2f89a54c7d6100a3f574e6fe6'
  end

  it 'can search previous archive versions when the latest book version is not found' do
    abl.each_book_with_previous_archive_version_fallback do |book|
      next unless book.uuid == '185cbf87-c72e-48f5-b51e-f14f21b5eabd'
      book.all_pages
    end
  end

  it 'can return a map of all page slugs by uuid' do
    expect(abl.slugs_by_page_uuid.size).to eq(24385)
  end
end
