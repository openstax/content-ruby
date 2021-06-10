require_relative 'html'

class OpenStax::Content::Fragment::Embedded < OpenStax::Content::Fragment::Html
  # Used to get the title
  TITLE_CSS = '[data-type="title"]'

  # Used to get the title if there are no title nodes
  LABEL_ATTRIBUTE = '[data-label]'

  # CSS to find embedded content urls
  TAGGED_URL_CSS = 'iframe.os-embed, a.os-embed, .os-embed iframe, .os-embed a'
  UNTAGGED_URL_CSS = 'iframe, a'

  CLASS_ATTRIBUTES = [ :iframe_classes, :iframe_title, :default_width, :default_height ]

  class << self
    attr_accessor *CLASS_ATTRIBUTES

    def inherited(subclass)
      CLASS_ATTRIBUTES.each do |class_attribute|
        subclass.send "#{class_attribute}=", send(class_attribute)
      end
    end
  end

  self.iframe_classes = ['os-embed']
  self.iframe_title = ''

  attr_reader :url, :width, :height

  def initialize(node:, title: nil, labels: nil)
    super

    @title ||= begin
      title_nodes = @node.css(TITLE_CSS)
      titles = title_nodes.empty? ? @node.css(LABEL_ATTRIBUTE).map do |label|
        label.attr('data-label')
      end : title_nodes.map { |node| node.content.strip }
      titles.uniq.join('; ')
    end

    url_node = @node.at_css(TAGGED_URL_CSS) || @node.css(UNTAGGED_URL_CSS).last

    @width = url_node.try(:[], 'width') || default_width
    @height = url_node.try(:[], 'height') || default_height
    @url = url_node.try(:[], 'src') || url_node.try(:[], 'href')

    if url_node.try(:name) == 'iframe'
      node_classes = url_node['class'].to_s.split(' ') + iframe_classes
      url_node['class'] = node_classes.uniq.join(' ')
      url_node['title'] ||= iframe_title
      # To always force the default iframe size, change ||= to =
      url_node['width'] ||= default_width
      url_node['height'] ||= default_height
    end

    @to_html = @node.to_html
  end

  def blank?
    url.nil? || url.empty?
  end
end
