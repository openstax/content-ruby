require_relative 'archive'
require_relative 'book'

class OpenStax::Content::Abl
  def initialize(url: nil, body: nil)
    @url = url
    @body = body
  end

  def url
    @url ||= OpenStax::Content.abl_url
  end

  def body
    @body ||= JSON.parse(Faraday.get(url).body).deep_symbolize_keys
  end

  def latest_version_by_collection_id
    @latest_version_by_collection_id ||= {}.tap do |hash|
      body[:approved_versions].each do |version|
        existing_version = hash[version[:collection_id]]

        next if !existing_version.nil? &&
                (existing_version[:content_version].split('.').map(&:to_i) <=>
                 version[:content_version].split('.').map(&:to_i)) >= 0

        hash[version[:collection_id]] = version
      end
    end
  end

  def approved_books(archive: OpenStax::Content::Archive.new)
    body[:approved_books].flat_map do |approved_book|
      if approved_book[:versions].nil?
        # CNX-hosted book
        version = latest_version_by_collection_id[approved_book[:collection_id]]

        next [] if version[:min_code_version] > archive.version

        approved_book[:books].map do |book|
          OpenStax::Content::Book.new(
            archive: archive,
            uuid: book[:uuid],
            version: version[:content_version].sub('1.', '')
          )
        end
      else
        # Git-hosted book
        approved_book[:versions].flat_map do |version|
          min_code_version = version[:min_code_version]

          next [] if min_code_version > archive.version

          commit_metadata = version[:commit_metadata]

          commit_metadata[:books].map do |book|
            OpenStax::Content::Book.new(
              archive: archive,
              uuid: book[:uuid],
              version: version[:commit_sha].first(7)
            )
          end
        end
      end
    end
  end
end
