# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
  gem 'rubocop'
end

group :development, :test do
  # Only for the specs that check it works along with deferred_columns.
  gem 'deferred_columns', path: '../deferred_columns'
  gem 'pg' unless ENV.fetch('DATABASE_URL', '').empty?
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.13'
  gem 'simplecov', require: false
  gem 'sqlite3', '>= 2.1'
end
