require_relative 'archive'
require_relative 'book'

class OpenStax::Content::Abl
  # Check back this many archive versions
  # If there are more than this number of archive versions still building, errors will happen
  DEFAULT_MAX_ARCHIVE_ATTEMPTS = 5

  attr_reader :partial_data

  def initialize(url: nil)
    @url = url
    @partial_data = false
  end

  def url
    @url ||= OpenStax::Content.abl_url
  end

  def body_string
    @body_string ||= Faraday.get(url).body
  end

  def body_array
    @body_array ||= JSON.parse(body_string, symbolize_names: true)
  end

  def digest
    Digest::SHA256.hexdigest body_string
  end

  def books(archive: OpenStax::Content::Archive.new)
    body_array.filter { |book| book[:code_version] <= archive.version }.map do |book|
      OpenStax::Content::Book.new(
        archive: archive,
        uuid: book[:uuid],
        version: book[:commit_sha][0..6],
        min_code_version: book[:code_version],
        slug: book[:slug],
        committed_at: book[:committed_at]
      )
    end
  end

  def each_book_with_previous_archive_version_fallback(max_attempts: DEFAULT_MAX_ARCHIVE_ATTEMPTS, &block)
    raise ArgumentError, 'no block given' if block.nil?
    raise ArgumentError, 'given block must accept the book as its first argument' if block.arity == 0

    books = OpenStax::Content::Abl.new.books
    attempt = 1

    until books.empty?
      previous_version = nil
      previous_archive = nil
      retry_books = []

      books.each do |book|
        begin
          block.call book
        rescue StandardError => exception
          raise exception if attempt >= max_attempts

          # Sometimes books in the latest archive fails to load (when the new version is still building)
          # Retry with an earlier version of archive, if possible
          previous_version ||= book.archive.previous_version

          if previous_version.nil?
            # There are no more earlier archive versions
            raise exception
          else
            previous_archive ||= OpenStax::Content::Archive.new version: previous_version

            retry_book = OpenStax::Content::Book.new(
              archive: previous_archive,
              uuid: book.uuid,
              version: book.version,
              slug: book.slug,
              min_code_version: book.min_code_version,
              committed_at: book.committed_at
            )

            # If the book requires an archive version that hasn't finished building yet, don't include it
            retry_books << retry_book if retry_book.valid?
          end
        end
      end

      books = retry_books
      attempt += 1
    end
  end

  def slugs_by_page_uuid(max_attempts: DEFAULT_MAX_ARCHIVE_ATTEMPTS)
    @slugs_by_page_uuid ||= {}.tap do |hash|
      @partial_data = false
      each_book_with_previous_archive_version_fallback(max_attempts: max_attempts) do |book|
        begin
          book.all_pages.each do |page|
            hash[page.uuid] ||= []
            hash[page.uuid] << { book: book.slug, page: page.slug }
          end
        rescue StandardError => exception
          @partial_data = true
          OpenStax::Content::logger.warn do
            "Failed to process slugs for book: #{book.uuid}. " \
            "Error: #{exception.class}: #{exception.message}"
          end
        end
      end

      hash.each { |uuid, slugs| slugs.uniq! }
    end
  end
end
