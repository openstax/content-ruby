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
    @body ||= JSON.parse(Faraday.get(url).body, symbolize_names: true)
  end

  def latest_approved_version_by_collection_id(archive: OpenStax::Content::Archive.new)
    {}.tap do |hash|
      body[:approved_versions].each do |version|
        next if version[:min_code_version] > archive.version

        existing_version = hash[version[:collection_id]]

        next if !existing_version.nil? &&
                (existing_version[:content_version].split('.').map(&:to_i) <=>
                 version[:content_version].split('.').map(&:to_i)) >= 0

        hash[version[:collection_id]] = version
      end
    end
  end

  def approved_books(archive: OpenStax::Content::Archive.new)
    # Can be removed once we have no more CNX books
    version_by_collection_id = latest_approved_version_by_collection_id(archive: archive)

    body[:approved_books].flat_map do |approved_book|
      if approved_book[:versions].nil?
        # CNX-hosted book
        version = version_by_collection_id[approved_book[:collection_id]]

        next [] if version.nil?

        approved_book[:books].map do |book|
          OpenStax::Content::Book.new(
            archive: archive,
            uuid: book[:uuid],
            version: version[:content_version].sub('1.', ''),
            slug: book[:slug],
            style: approved_book[:style]
          )
        end
      else
        # Git-hosted book
        approved_book[:versions].flat_map do |version|
          next [] if version[:min_code_version] > archive.version

          commit_metadata = version[:commit_metadata]

          commit_metadata[:books].map do |book|
            OpenStax::Content::Book.new(
              archive: archive,
              uuid: book[:uuid],
              version: version[:commit_sha][0..6],
              slug: book[:slug],
              style: book[:style]
            )
          end
        end
      end
    end
  end
end
