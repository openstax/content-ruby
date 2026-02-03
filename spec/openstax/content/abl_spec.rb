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

  it 'sets partial_data to true when a book fails to process', vcr: { allow_unused_http_interactions: true } do
    archive_version = '20250522.165258'
    archive_versions = [archive_version]
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_wrap_original do |method, *args|
      archive_versions
    end

    # Stub previous_version to return the appropriate previous version
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:previous_version).and_wrap_original do |method, *args|
      archive = method.receiver
      current_index = archive_versions.index(archive.version)
      current_index && current_index > 0 ? archive_versions[current_index - 1] : nil
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
    first_book_processed = false
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_wrap_original do |method, *args|
      # Fail for the first book encountered
      if first_book_processed
        # Return fake pages for the second book
        [
          OpenStruct.new(uuid: '11111111-1111-1111-1111-111111111111', slug: 'test-page-1'),
          OpenStruct.new(uuid: '22222222-2222-2222-2222-222222222222', slug: 'test-page-2')
        ]
      else
        first_book_processed = true
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

  it 'sets partial_data to true after exhausting all archive version retries' do
    # Set up three archive versions to test the retry loop
    archive_versions = ['20250520.165258', '20250521.165258', '20250522.165258']
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_wrap_original do |method, *args|
      archive_versions
    end

    # Stub previous_version to return the appropriate previous version
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:previous_version).and_wrap_original do |method, *args|
      archive = method.receiver
      current_index = archive_versions.index(archive.version)
      current_index && current_index > 0 ? archive_versions[current_index - 1] : nil
    end

    # Create two books, each with different UUIDs to ensure proper isolation
    allow_any_instance_of(OpenStax::Content::Abl).to receive(:books).and_wrap_original do |method, *args|
      archive = OpenStax::Content::Archive.new(version: archive_versions.last)
      result = []
      result << OpenStax::Content::Book.new(
        archive: archive,
        uuid: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        version: '1.0',
        min_code_version: archive_versions.first,
        slug: 'failing-book',
        committed_at: '2026-01-21T21:45:57+00:00'
      )
      result << OpenStax::Content::Book.new(
        archive: archive,
        uuid: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        version: '1.0',
        min_code_version: archive_versions.first,
        slug: 'success-book',
        committed_at: '2026-01-21T21:45:57+00:00'
      )
      result
    end

    attempt_count = {}

    # Stub to make the first book fail for ALL archive versions
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_wrap_original do |method, *args, &block|
      book = args[0].is_a?(OpenStax::Content::Book) ? args[0] : method.receiver

      if book.slug == 'failing-book'
        # Track attempts for this book
        attempt_count[book.uuid] ||= 0
        attempt_count[book.uuid] += 1
        raise StandardError, "Simulated failure for attempt #{attempt_count[book.uuid]}"
      else
        # Success book returns fake pages
        [
          OpenStruct.new(uuid: 'cccccccc-cccc-cccc-cccc-cccccccccccc', slug: 'success-page-1'),
          OpenStruct.new(uuid: 'dddddddd-dddd-dddd-dddd-dddddddddddd', slug: 'success-page-2')
        ]
      end
    end

    # Expect warnings to be logged for failed attempts
    expect(OpenStax::Content::logger).to receive(:warn).at_least(:once)

    # Should start as false
    expect(abl.partial_data).to be false

    result = abl.slugs_by_page_uuid

    # Should still return results from the successful book
    expect(result).to be_a(Hash)
    expect(result).not_to be_empty
    expect(result['cccccccc-cccc-cccc-cccc-cccccccccccc']).not_to be_nil

    # Should have tried multiple times (initial + retries)
    expect(attempt_count['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa']).to eq(3)
    expect(abl.partial_data).to be true
  end

  it 'raises exception when allow_partial_data is false and a book fails' do
    archive_version = '20250522.165258'
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_wrap_original do |method, *args|
      [archive_version]
    end
    allow_any_instance_of(OpenStax::Content::Abl).to receive(:books).and_wrap_original do |method, *args|
      archive = OpenStax::Content::Archive.new(version: archive_version)
      [OpenStax::Content::Book.new(
        archive: archive,
        uuid: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        version: '1.0',
        min_code_version: archive_version,
        slug: 'failing-book',
        committed_at: '2026-01-21T21:45:57+00:00'
      )]
    end

    # Stub to make the book always fail
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_raise(StandardError, 'Test error')

    # Should raise exception when allow_partial_data is false
    expect do
      abl.each_book_with_previous_archive_version_fallback(allow_partial_data: false) do |book|
        book.all_pages
      end
    end.to raise_error(StandardError, 'Test error')
  end

  it 'sets partial_data to true when previous archive version is below min_code_version' do
    # Current archive version and a previous version that's too old
    current_version = '20250522.165258'
    previous_version = '20250520.165258'
    # Book requires a version newer than the previous version
    min_code_version = '20250521.165258'

    archive_versions = [previous_version, current_version]
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_return(archive_versions)

    allow_any_instance_of(OpenStax::Content::Archive).to receive(:previous_version).and_wrap_original do |method, *args|
      archive = method.receiver
      current_index = archive_versions.index(archive.version)
      current_index && current_index > 0 ? archive_versions[current_index - 1] : nil
    end

    allow_any_instance_of(OpenStax::Content::Abl).to receive(:books).and_wrap_original do |method, *args|
      archive = OpenStax::Content::Archive.new(version: current_version)
      [
        OpenStax::Content::Book.new(
          archive: archive,
          uuid: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          version: '1.0',
          min_code_version: min_code_version,
          slug: 'book-with-high-min-version',
          committed_at: '2026-01-21T21:45:57+00:00'
        ),
        OpenStax::Content::Book.new(
          archive: archive,
          uuid: '11111111-1111-1111-1111-111111111111',
          version: '1.0',
          min_code_version: previous_version,
          slug: 'success-book',
          committed_at: '2026-01-21T21:45:57+00:00'
        )
      ]
    end

    # First book fails on current archive, second book succeeds
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_wrap_original do |method, *args|
      book = method.receiver
      if book.slug == 'book-with-high-min-version'
        raise StandardError, 'Simulated archive error'
      else
        [OpenStruct.new(uuid: '22222222-2222-2222-2222-222222222222', slug: 'success-page')]
      end
    end

    # Expect a warning about invalid book for archive version
    expect(OpenStax::Content::logger).to receive(:warn).at_least(:once)

    expect(abl.partial_data).to be false

    result = {}
    abl.each_book_with_previous_archive_version_fallback do |book|
      book.all_pages.each do |page|
        result[page.uuid] = page.slug
      end
    end

    # Should have results from the successful book
    expect(result).not_to be_empty
    expect(result['22222222-2222-2222-2222-222222222222']).to eq('success-page')

    # Should mark data as partial because the first book couldn't fall back
    expect(abl.partial_data).to be true
  end

  it 'raises exception when previous archive is invalid and allow_partial_data is false' do
    current_version = '20250522.165258'
    previous_version = '20250520.165258'
    # Book requires a version newer than the previous version
    min_code_version = '20250521.165258'

    archive_versions = [previous_version, current_version]
    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_return(archive_versions)

    allow_any_instance_of(OpenStax::Content::Archive).to receive(:previous_version).and_wrap_original do |method, *args|
      archive = method.receiver
      current_index = archive_versions.index(archive.version)
      current_index && current_index > 0 ? archive_versions[current_index - 1] : nil
    end

    allow_any_instance_of(OpenStax::Content::Abl).to receive(:books).and_wrap_original do |method, *args|
      archive = OpenStax::Content::Archive.new(version: current_version)
      [OpenStax::Content::Book.new(
        archive: archive,
        uuid: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        version: '1.0',
        min_code_version: min_code_version,
        slug: 'book-with-high-min-version',
        committed_at: '2026-01-21T21:45:57+00:00'
      )]
    end

    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_raise(StandardError, 'Simulated archive error')

    # Should raise the original exception when allow_partial_data is false
    expect do
      abl.each_book_with_previous_archive_version_fallback(allow_partial_data: false) do |book|
        book.all_pages
      end
    end.to raise_error(StandardError, 'Simulated archive error')
  end

  it 'stops retrying once an archive version becomes invalid' do
    # Set up multiple archive versions where only some are valid for the book
    archive_versions = ['20250518.165258', '20250519.165258', '20250520.165258', '20250521.165258', '20250522.165258']
    current_version = archive_versions.last
    # Book requires version 20250520 or higher, so 20250518 and 20250519 are invalid
    min_code_version = '20250520.165258'

    allow_any_instance_of(OpenStax::Content::Archive).to receive(:versions).and_return(archive_versions)

    allow_any_instance_of(OpenStax::Content::Archive).to receive(:previous_version).and_wrap_original do |method, *args|
      archive = method.receiver
      current_index = archive_versions.index(archive.version)
      current_index && current_index > 0 ? archive_versions[current_index - 1] : nil
    end

    allow_any_instance_of(OpenStax::Content::Abl).to receive(:books).and_wrap_original do |method, *args|
      archive = OpenStax::Content::Archive.new(version: current_version)
      [OpenStax::Content::Book.new(
        archive: archive,
        uuid: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        version: '1.0',
        min_code_version: min_code_version,
        slug: 'test-book',
        committed_at: '2026-01-21T21:45:57+00:00'
      )]
    end

    attempted_versions = []
    allow_any_instance_of(OpenStax::Content::Book).to receive(:all_pages).and_wrap_original do |method, *args|
      book = method.receiver
      attempted_versions << book.archive.version
      raise StandardError, 'Simulated archive error'
    end

    expect(OpenStax::Content::logger).to receive(:warn).at_least(:once)

    abl.each_book_with_previous_archive_version_fallback do |book|
      book.all_pages
    end

    # Should have tried: 20250522, 20250521, 20250520
    # Should NOT have tried 20250519 because 20250520 failed and 20250519 < min_code_version
    # Wait, that's not right. Let me re-read the logic...
    # Actually, it tries current (20250522), fails, then creates book with 20250521, checks valid? (true), tries, fails,
    # creates book with 20250520, checks valid? (true, since 20250520 >= 20250520), tries, fails,
    # creates book with 20250519, checks valid? (false, since 20250519 < 20250520), breaks
    # So it should attempt 20250522, 20250521, 20250520, then stop when 20250519 is invalid
    expect(attempted_versions).to eq(['20250522.165258', '20250521.165258', '20250520.165258'])
    expect(abl.partial_data).to be true
  end
end
