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

  it 'sets partial_data to true when a book fails to process', vcr: { cassette_name: 'OpenStax_Content_Abl/can_return_a_map_of_all_page_slugs_by_uuid' } do
    # Stub to make one book fail during all_pages processing
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_wrap_original do |method, *args|
      # Fail for the first book encountered
      if @first_book_processed
        method.call(*args)
      else
        @first_book_processed = true
        raise StandardError, 'Simulated archive error'
      end
    end

    # Expect a warning to be logged
    expect(OpenStax::Content::logger).to receive(:warn).at_least(:once)
    # Should start as false
    expect(abl.partial_data).to be false

    result = abl.slugs_by_page_uuid

    # Should still return results (from other books that succeeded)
    expect(result).to be_a(Hash)
    expect(result).not_to be_empty

    # Should mark data as partial
    expect(abl.partial_data).to be true
  end
end
