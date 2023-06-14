require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Book, vcr: VCR_OPTS do
  let(:archive_version)   { MINI_BOOK_ARCHIVE_VERSION }
  subject(:book)          { MINI_BOOK }

  let(:book_uuid)         { MINI_BOOK_HASH['id'] }
  let(:book_version)      { MINI_BOOK_HASH['version'] }
  let(:expected_book_url) do
    "https://#{OpenStax::Content.domain}/#{OpenStax::Content.archive_path
    }/#{archive_version}/contents/#{book_uuid}@#{book_version}.json"
  end

  it 'provides info about the book with the given id' do
    expect(book.archive.version).to eq archive_version
    expect(book.uuid).to eq book_uuid
    expect(book.version).to eq book_version
    expect(book.hash).not_to be_empty
    expect(book.url).to eq expected_book_url
    expect(book.title).to be_a(String)
    expect(book.tree).not_to be_nil
    expect(book.root_book_part).to be_a OpenStax::Content::BookPart
  end

  it 'delegates all_book_parts to root_book_part' do
    all_book_parts = [ OpenStax::Content::BookPart.new(hash: MINI_BOOK_CHAPTER_HASHES.first) ]
    expect(book.root_book_part).to receive(:all_book_parts).and_return(all_book_parts)
    expect(book.all_book_parts).to eq all_book_parts
  end

  it 'delegates all_pages to root_book_part' do
    all_pages = [ OpenStax::Content::Page.new(hash: MINI_BOOK_PAGE_HASHES.first) ]
    expect(book.root_book_part).to receive(:all_pages).and_return(all_pages)
    expect(book.all_pages).to eq all_pages
  end

  it 'knows if the version plus archive version combination is valid or not' do
    expect(book).to be_valid
    book.instance_variable_set('@min_code_version', MINI_BOOK_ARCHIVE_VERSION)
    expect(book).to be_valid
    new_time = Time.strptime(MINI_BOOK_ARCHIVE_VERSION, '%Y%m%d.%H%M%S') + 1
    book.instance_variable_set('@min_code_version', new_time.strftime('%Y%m%d.%H%M%S'))
    expect(book).not_to be_valid
  end

  it 'can search previous archive versions when the latest book version is not found' do
    abl = OpenStax::Content::Abl.new
    approved_book = abl.approved_books.find { |book| book.uuid == '185cbf87-c72e-48f5-b51e-f14f21b5eabd' }
    approved_book.with_previous_archive_version_fallback { |book| book.all_pages }
  end
end
