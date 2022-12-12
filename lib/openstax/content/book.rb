require 'forwardable'
require_relative 'book_part'

class OpenStax::Content::Book
  extend Forwardable

  attr_reader :archive, :uuid, :version, :slug, :style, :min_code_version, :committed_at

  def initialize(
    archive:, uuid:, version:,
    url: nil, hash: nil, slug: nil, style: nil, min_code_version: nil, committed_at: nil
  )
    @archive = archive
    @uuid = uuid
    @version = version
    @url = url
    @hash = hash
    @slug = slug
    @style = style
    @min_code_version = min_code_version
    @committed_at = committed_at
  end

  def valid?
    min_code_version.nil? || min_code_version <= archive.version
  end

  def url
    @url ||= archive.url_for "#{uuid}@#{version}"
  end

  def url_fragment
    @url_fragment ||= url.chomp('.json')
  end

  def hash
    @hash ||= archive.json url
  end

  def baked
    @baked ||= hash['baked']
  end

  def collated
    @collated ||= hash.fetch('collated', false)
  end

  def short_id
    @short_id ||= hash['shortId']
  end

  def title
    @title ||= hash.fetch('title')
  end

  def tree
    @tree ||= hash.fetch('tree')
  end

  def root_book_part
    @root_book_part ||= OpenStax::Content::BookPart.new(hash: tree, is_root: true, book: self)
  end

  def_delegator :root_book_part, :all_pages

  def with_previous_archive_version_fallback(&block)
    raise ArgumentError, 'no block given' if block.nil?
    raise ArgumentError, 'given block must accept the book as its first argument' if block.arity == 0

    book = self

    loop do
      begin
        return block.call book
      rescue StandardError => exception
        # Sometimes books in the ABL fail to load
        # Retry with an earlier version of archive, if possible
        previous_archive_version = book.archive.previous_version
        raise exception if previous_archive_version.nil?

        book = OpenStax::Content::Book.new(
          archive: OpenStax::Content::Archive.new(version: previous_archive_version),
          uuid: book.uuid,
          version: book.version,
          slug: book.slug,
          style: book.style,
          min_code_version: book.min_code_version,
          committed_at: book.committed_at
        )
        raise exception unless book.valid?
      end
    end
  end
end
