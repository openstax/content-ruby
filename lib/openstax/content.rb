module OpenStax
  module Content
    class << self
      attr_accessor :abl_url, :archive_path, :bucket_name, :domain, :logger,
                    :s3_region, :s3_access_key_id, :s3_secret_access_key

      def configure
        yield self
      end
    end
  end
end

Dir["#{__dir__}/content/**/*.rb"].each { |file| require file }
