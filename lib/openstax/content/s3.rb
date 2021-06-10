require 'aws-sdk-s3'

class OpenStax::Content::S3
  def initialize
    @ls = {}
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

  def ls(archive_version = nil)
    return @ls[archive_version] unless @ls[archive_version].nil?
    return unless bucket_configured?

    archive_path = OpenStax::Content.archive_path.chomp('/')

    if archive_version.nil?
      prefix = "#{archive_path}/"
      delimiter = '/'
    else
      prefix = "#{archive_path}/#{archive_version}/contents/"
      delimiter = ':'
    end

    @ls[archive_version] = client.list_objects_v2(
      bucket: bucket_name, prefix: prefix, delimiter: delimiter
    ).flat_map(&:common_prefixes).map do |common_prefix|
      common_prefix.prefix.sub(prefix, '').chomp(delimiter)
    end
  end
end
