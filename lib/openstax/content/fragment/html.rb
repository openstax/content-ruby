require 'addressable/uri'

require_relative '../fragment'

class OpenStax::Content::Fragment::Html < OpenStax::Content::Fragment
  attr_reader :to_html

  def initialize(node:, title: nil, labels: nil)
    super

    @node = Nokogiri::HTML.fragment node.to_html
    @to_html = @node.to_html
  end

  def as_json(*args)
    # Don't attempt to serialize @node (it would fail)
    super.except('node')
  end

  def html?
    !to_html.empty?
  end

  def blank?
    !html?
  end

  def node
    @node ||= Nokogiri::HTML.fragment to_html
  end

  def has_css?(css, custom_css)
    !node.at_css(css, custom_css).nil?
  end

  def append(new_node)
    (node.at_css('body') || node.root) << new_node

    @to_html = node.to_html
  end

  def transform_links!
    node.css('[href]').each do |link|
      href = link.attributes['href']
      uri = Addressable::URI.parse(href.value) rescue nil

      # Modify only fragment-only links
      next if uri.nil? || uri.absolute? || !uri.path.empty?

      # Abort if there is no target or it contains double quotes
      # or it's still present in this fragment
      target = uri.fragment
      next if target.nil? || target.empty? || target.include?('"') ||
              node.at_css("[id=\"#{target}\"], [name=\"#{target}\"]")

      # Change the link to point to the reference view
      href.value = "#{@reference_view_url}##{target}"
    end unless @reference_view_url.nil?

    @to_html = node.to_html
  end
end