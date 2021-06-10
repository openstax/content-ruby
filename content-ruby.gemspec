$:.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'openstax/content/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |gem|
  gem.name        = 'openstax_content'
  gem.version     = OpenStax::Content::VERSION
  gem.authors     = [ 'Dante Soares' ]
  gem.email       = [ 'dante.m.soares@rice.edu' ]
  gem.homepage    = 'https://github.com/openstax/content-ruby'
  gem.license     = 'AGPL-3.0'
  gem.summary     = 'Ruby bindings to read and parse the OpenStax ABL and the content archive'
  gem.description = 'Ruby bindings to read and parse the OpenStax ABL and the content archive'

  gem.files = Dir['lib/**/*'] + [ 'LICENSE', 'README.md' ]

  gem.add_dependency 'aws-sdk-s3'
  gem.add_dependency 'faraday'
  gem.add_dependency 'nokogiri'

  gem.add_development_dependency 'dotenv'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'vcr'
end
