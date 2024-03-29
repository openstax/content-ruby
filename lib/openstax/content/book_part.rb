require_relative 'title'
require_relative 'page'

class OpenStax::Content::BookPart
  def initialize(hash: {}, is_root: false, book: nil)
    @hash = hash
    @is_root = is_root
    @book = book
  end

  attr_reader :hash, :is_root, :book

  def parsed_title
    @parsed_title ||= OpenStax::Content::Title.new hash.fetch('title')
  end

  def book_location
    @book_location ||= parsed_title.book_location
  end

  def title
    @title ||= parsed_title.text
  end

  # Old content used to have id == "subcol" for units and chapters
  # If we encounter that, just assign a random UUID to them
  def uuid
    @uuid ||= begin
      uuid = hash['id']
      uuid.nil? || uuid == 'subcol' ? SecureRandom.uuid : uuid.split('@').first
    end
  end

  def contents
    @contents ||= hash.fetch('contents')
  end

  def parts
    @parts ||= contents.map do |hash|
      if hash.has_key? 'contents'
        self.class.new book: book, hash: hash
      else
        OpenStax::Content::Page.new book: book, hash: hash
      end
    end
  end

  def all_book_parts
    @all_book_parts ||= parts.flat_map do |part|
      part.is_a?(OpenStax::Content::BookPart) ? [ part ] + part.all_book_parts : []
    end
  end

  def all_pages
    @all_pages ||= parts.flat_map do |part|
      part.is_a?(OpenStax::Content::Page) ? [ part ] : part.all_pages
    end
  end
end
