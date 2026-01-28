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
    archive_version = '20250522.165258'
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_wrap_original do |method, *args|
      ['20250522.165258']
    end
    allow_any_instance_of(OpenStax::Content::Abl).to receive(:books).and_wrap_original do |method, *args|
      archive = OpenStax::Content::Archive.new(version: archive_version)
      result = []
      ['0000000', '0000001'].each do |version|
        result << OpenStax::Content::Book.new(
          archive: archive,
          uuid: '00000000-0000-0000-0000-000000000000',
          version: version,
          min_code_version: archive_version,
          slug: 'test-book',
          committed_at: '2026-01-21T21:45:57+00:00'
        )
      end
      result
    end
    # Stub to make one book fail during all_pages processing
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_wrap_original do |method, *args|
      # Fail for the first book encountered
      if @first_book_processed
        # Return fake pages for the second book
        [
          OpenStruct.new(uuid: '11111111-1111-1111-1111-111111111111', slug: 'test-page-1'),
          OpenStruct.new(uuid: '22222222-2222-2222-2222-222222222222', slug: 'test-page-2')
        ]
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
