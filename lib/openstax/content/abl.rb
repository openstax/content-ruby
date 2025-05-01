require_relative 'archive'
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
end
