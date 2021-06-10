class OpenStax::Content::Title
  attr_reader :book_location, :text

  def initialize(title)
    return if title.nil?

    @text = title

    part = Nokogiri::HTML.fragment(title)
    number_node = part.at_css('.os-number')
    unless number_node.nil?
      @book_location = number_node.text.gsub(/[^\.\d]/, '').split('.').map do |number|
        Integer(number) rescue nil
      end.compact
    end
    @book_location = [] if @book_location.nil?
  end
end
