require_relative 'book'

class OpenStax::Content::Abl
  def initialize(url: nil)
    @url = url
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

  def books
    body_array.map do |book|
      OpenStax::Content::Book.new(
        code_version: book[:code_version],
        uuid: book[:uuid],
        version: book[:commit_sha][0..6],
        slug: book[:slug],
        committed_at: book[:committed_at]
      )
    end
  end
end
