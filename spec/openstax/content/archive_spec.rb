require 'spec_helper'
require 'vcr_helper'

RSpec.describe OpenStax::Content::Archive, vcr: VCR_OPTS do
  subject(:archive)          { described_class.new version: MINI_BOOK_ARCHIVE_VERSION }
  let(:expected_base_url)    { 'https://openstax.org' }
  let(:expected_archive_url) { "#{expected_base_url}/apps/archive/#{MINI_BOOK_ARCHIVE_VERSION}" }


  it 'can generate urls for collections' do
    [ '', '.xhtml', '.json' ].each do |extension|
      expect(archive.url_for("book-uuid@book-version#{extension}")).to(
        eq "#{expected_archive_url}/contents/book-uuid@book-version.json"
      )
    end
  end

  it 'can generate urls for resources' do
    expect(archive.url_for('../resources/image')).to(eq "#{expected_archive_url}/resources/image")
  end

  it 'can generate urls for pages' do
    [ '', '.xhtml', '.json' ].each do |extension|
      expect(archive.url_for("book-uuid@book-version:page-uuid#{extension}")).to(
        eq "#{expected_archive_url}/contents/book-uuid@book-version:page-uuid.json"
      )
    end
  end

  it 'can fetch and parse collection JSON' do
    collection_hash = archive.json "#{MINI_BOOK.uuid}@#{MINI_BOOK.version}"

    expect(collection_hash).to be_a Hash
    expect(collection_hash).not_to be_empty
  end

  it 'can find book and page slugs' do
    book_id = MINI_BOOK.uuid
    expect(archive.slug book_id).to eq 'college-physics-courseware'

    page_id = MINI_BOOK_PAGE_HASHES.first['id']
    expect(archive.slug "#{book_id}:#{page_id}").to eq '4-2-newtons-first-law-of-motion-inertia'
  end

  it 'can generate webview urls for pages' do
    book_id = "#{MINI_BOOK.uuid}@#{MINI_BOOK.version}"
    page_id = MINI_BOOK_PAGE_HASHES.first['id']
    expect(archive.webview_uri_for("#{book_id}:#{page_id}").to_s).to eq(
      "#{expected_base_url
      }/books/college-physics-courseware/pages/4-2-newtons-first-law-of-motion-inertia"
    )
  end
end
