require 'aws-sdk-s3'

class OpenStax::Content::S3
  def initialize
    @ls = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = {} } }
  end

  def bucket_name
    OpenStax::Content.bucket_name
  end

  def bucket_configured?
    !bucket_name.nil? && !bucket_name.empty?
  end

  def client
    @client ||= Aws::S3::Client.new(
      region: OpenStax::Content.s3_region,
      access_key_id: OpenStax::Content.s3_access_key_id,
      secret_access_key: OpenStax::Content.s3_secret_access_key
    )
  end

  # Returns the archive path for the given archive_version, book_id, page_uuid and extension
  # If not all arguments are given, returns the prefix instead
  def path_for(archive_version = nil, book_id = nil, page_uuid = nil, extension = nil)
    archive_path = OpenStax::Content.archive_path.chomp('/')

    if archive_version.nil?
      "#{archive_path}/"
    elsif book_id.nil?
      "#{archive_path}/#{archive_version}/contents/"
    elsif page_uuid.nil?
      "#{archive_path}/#{archive_version}/contents/#{book_id}:"
    elsif extension.nil?
      "#{archive_path}/#{archive_version}/contents/#{book_id}:#{page_uuid}."
    else
      "#{archive_path}/#{archive_version}/contents/#{book_id}:#{page_uuid}.#{extension}"
    end
  end

  # Without an archive version, returns a list of archive versions
  # With an archive version, returns a list of book ids (uuid@version)
  # With an archive version and a book, returns a list of page uuids
  # With an archive version, book id and page uuid, returns the available extensions, if any
  def ls(archive_version = nil, book_id = nil, page_uuid = nil)
    return @ls[archive_version][book_id][page_uuid] \
      unless @ls[archive_version][book_id][page_uuid].nil?
    return unless bucket_configured?

    prefix = path_for archive_version, book_id, page_uuid

    delimiter = if archive_version.nil?
      '/'
    elsif book_id.nil?
      ':'
    elsif page_uuid.nil?
      '.'
    else
      nil
    end

    responses = client.list_objects_v2 bucket: bucket_name, prefix: prefix, delimiter: delimiter

    @ls[archive_version][book_id][page_uuid] = if page_uuid.nil?
      responses.flat_map(&:common_prefixes).map do |common_prefix|
        common_prefix.prefix.sub(prefix, '').chomp(delimiter)
      end
    else
      responses.flat_map(&:contents).map { |content| content.key.sub(prefix, '') }
    end
  end

  # Checks all books for the given page uuid and returns the path to the first one found
  def find_page(page_uuid, archive_version: nil, extension: 'json')
    archive_version ||= ls.last

    ls(archive_version).each do |book_id|
      return path_for(archive_version, book_id, page_uuid, extension) \
        if ls(archive_version, book_id, page_uuid).include?(extension)
    end

    nil
  end
end
