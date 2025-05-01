require 'forwardable'
require_relative 'archive'
require_relative 'book_part'

class OpenStax::Content::Book
  extend Forwardable

  attr_reader :uuid, :version, :slug, :code_version, :committed_at

  def initialize(code_version:, uuid:, version:, archive: nil, url: nil, hash: nil, slug: nil, committed_at: nil)
    @code_version = code_version
    @uuid = uuid
    @version = version
    @archive = archive
    @url = url
    @hash = hash
    @slug = slug
    @committed_at = committed_at
  end

  def archive
    @archive ||= OpenStax::Content::Archive.new(version: code_version)
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

  def_delegators :root_book_part, :all_book_parts, :all_pages
end
