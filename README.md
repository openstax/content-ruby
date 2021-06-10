[![Tests](https://github.com/openstax/content-ruby/workflows/Tests/badge.svg)](https://github.com/openstax/content-ruby/actions/workflows/tests.yml)

# content-ruby
Ruby bindings to read and parse the OpenStax ABL and the content archive

## Installation
Add this gem to your Gemfile and then add the following configuration to your boot
(for example, in a Rails initializer):

```rb
OpenStax::Content.configure do |config|
  config.abl_url = ENV['OPENSTAX_CONTENT_ABL_URL']
  config.archive_path = ENV['OPENSTAX_CONTENT_ARCHIVE_PATH']
  config.bucket_name = ENV['OPENSTAX_CONTENT_BUCKET_NAME']
  config.domain = ENV['OPENSTAX_CONTENT_DOMAIN']
  config.exercises_search_api_url = ENV['OPENSTAX_CONTENT_EXERCISES_SEARCH_API_URL']
  config.logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  config.s3_region = ENV['OPENSTAX_CONTENT_S3_REGION']
  config.s3_access_key_id = ENV['OPENSTAX_CONTENT_S3_ACCESS_KEY_ID']
  config.s3_secret_access_key = ENV['OPENSTAX_CONTENT_S3_SECRET_ACCESS_KEY']
end
```

It's probably a good idea to read these values from environment variables
s3_access_key_id and s3_secret_access_key are optional (you can use AWS instance roles instead)

## Usage

### Approved Book List (to get approved books and approved versions)
```rb
abl = OpenStax::Content::Abl.new
approved_books = abl.approved_books
approved_versions = abl.approved_versions
```

### S3 Bucket Listing (to get latest archive and book versions)
```rb
s3 = OpenStax::Content::S3.new
if s3.bucket_configured?
  latest_archive_version = s3.ls.last
  latest_book_ids = s3.ls latest_archive_version
  chosen_book = latest_book_ids.sample
  book_uuid, book_version = chosen_book.split('@', 2)
  book = OpenStax::Content::Book.new(
    archive_version: latest_archive_version, uuid: book_uuid, version: book_version
  )
end
```

### Archive (to create archive links, load content and get book and page slugs)
```rb
archive = OpenStax::Content::Archive.new latest_archive_version

book_id = "#{book_uuid}@#{book_version}"
page_id = "#{book_id}:#{page_uuid}"

book_url = archive.url_for book_id
page_url = archive.url_for page_id

book_json = archive.fetch book_id
page_json = archive.fetch page_id

book_hash = archive.json book_id
page_hash = archive.json page_id

book_slug = archive.slug book_id # or book_uuid
page_slug = archive.slug page_id # or "#{book_uuid}:#{page_uuid}"
```

### Fragment Splitter (to split pages and create interactive readings)
```rb
fragment_splitter = OpenStax::Content::FragmentSplitter.new(
  book.reading_processing_instructions, reference_view_url
)
fragment_splitter.split_into_fragments page.root
```

## Testing

To run all existing tests for this gem, simply execute the following from the main folder:

```sh
$ rake
```

## Contributing

1. Fork the openstax/content-ruby repo on Github
2. Create a feature or bugfix branch (`git checkout -b my-new-feature`)
3. Write tests for the feature/bugfix
4. Implement the new feature/bugfix
5. Make sure both new and old tests pass (`rake`)
6. Commit your changes (`git commit -am 'Added some feature'`)
7. Push the branch (`git push origin my-new-feature`)
8. Create a new Pull Request to openstax/content-ruby on Github

## License

This gem is distributed under the terms of the AGPLv3 license.
See the LICENSE file for details.
