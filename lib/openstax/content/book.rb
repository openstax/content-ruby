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
end
