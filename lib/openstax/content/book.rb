require_relative 'archive'
require_relative 'book_part'

class OpenStax::Content::Book
  attr_reader :archive, :uuid, :version

  def initialize(archive:, uuid:, version:)
    @archive = archive
    @uuid = uuid
    @version = version
  end

  def url
    @url ||= archive.url_for "#{uuid}@#{version}"
  end

  def hash
    @hash ||= archive.json url
  end

  def url_fragment
    @url_fragment ||= url.chomp('.json')
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
end
