# frozen_string_literal: true

source 'https://rubygems.org'
gemspec
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem 'bundler', '>= 1.1.0'
  gem 'rake'
  gem 'rdoc'
end

group :test do
  gem 'minitest', '~> 5.0'
  gem 'simplecov', '~> 1.3', require: false
end

group :lint do
  gem 'rubocop', '~> 1.86.0', require: false
  gem 'rubocop-erb', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end
