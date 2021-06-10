require 'spec_helper'

RSpec.describe OpenStax::Content::Book do
  let(:archive_version)   { MINI_BOOK_ARCHIVE_VERSION }
  subject(:book)          { MINI_BOOK }

  let(:book_uuid)         { MINI_BOOK_HASH['id'] }
  let(:book_version)      { MINI_BOOK_HASH['version'] }
  let(:expected_book_url) do
    "https://#{OpenStax::Content.domain}/#{OpenStax::Content.archive_path
    }/#{archive_version}/contents/#{book_uuid}@#{book_version}.json"
  end

  it "provides info about the book with the given id" do
    expect(book.archive_version).to eq archive_version
    expect(book.uuid).to eq book_uuid
    expect(book.version).to eq book_version
    expect(book.hash).not_to be_empty
    expect(book.url).to eq expected_book_url
    expect(book.title).to be_a(String)
    expect(book.tree).not_to be_nil
    expect(book.root_book_part).to be_a OpenStax::Content::BookPart
  end
end
