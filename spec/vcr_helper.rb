require 'vcr'

VCR::Configuration.class_exec do
  # Reference: https://github.com/vcr/vcr/blob/master/lib/vcr/configuration.rb#L225
  def filter_request_header(header, tag = nil)
    before_record(tag) do |interaction|
      (interaction.request.headers[header] || []).each_with_index do |orig_text, index|
        placeholder = "<#{header} #{index + 1}>"
        log "before_record: replacing #{orig_text.inspect} with #{placeholder.inspect}"
        interaction.filter!(orig_text, placeholder)
      end
    end

    before_playback(tag) do |interaction|
      (interaction.request.headers[header] || []).each_with_index do |orig_text, index|
        placeholder = "<#{header} #{index + 1}>"
        log "before_playback: replacing #{orig_text.inspect} with #{placeholder.inspect}"
        interaction.filter!(placeholder, orig_text)
      end
    end
  end

  def filter_response_header(header, tag = nil)
    before_record(tag) do |interaction|
      (interaction.response.headers[header] || []).each_with_index do |orig_text, index|
        placeholder = "<#{header} #{index + 1}>"
        log "before_record: replacing #{orig_text.inspect} with #{placeholder.inspect}"
        interaction.filter!(orig_text, placeholder)
      end
    end

    before_playback(tag) do |interaction|
      (interaction.response.headers[header] || []).each_with_index do |orig_text, index|
        placeholder = "<#{header} #{index + 1}>"
        log "before_playback: replacing #{orig_text.inspect} with #{placeholder.inspect}"
        interaction.filter!(placeholder, orig_text)
      end
    end
  end
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.allow_http_connections_when_no_cassette = false
  c.ignore_localhost = true
  c.preserve_exact_body_bytes { |http_message| !http_message.body.valid_encoding? }

  # Turn on debug logging
  # c.debug_logger = $stderr

  [
    :abl_url,
    :archive_path,
    :bucket_name,
    :domain,
    :s3_region,
    :s3_access_key_id,
    :s3_secret_access_key
  ].each { |secret| c.filter_sensitive_data("<#{secret}>") { OpenStax::Content.send secret } }

  [ 'Authorization', 'Cookie', 'X-Amz-Security-Token' ].each do |request_header|
    c.filter_request_header request_header
  end

  [ 'Set-Cookie', 'X-Amz-Request-Id', 'X-Amz-Id-2' ].each do |response_header|
    c.filter_response_header response_header
  end
end

VCR_OPTS = {
  # This should default to :none
  record: ENV.fetch('VCR_OPTS_RECORD', :none).to_sym,
  allow_unused_http_interactions: false
}
