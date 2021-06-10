class OpenStax::Content::Abl
  def body
    @body ||= JSON.parse(Faraday.get(OpenStax::Content.abl_url).body).deep_symbolize_keys
  end

  def approved_books
    body[:approved_books]
  end

  def approved_versions
    body[:approved_versions]
  end
end
