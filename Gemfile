# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
  gem 'rubocop'
end

group :development, :test do
  # Only for the specs that check it works along with deferred_columns. Uses a
  # sibling checkout when there's one, to test unreleased changes of both gems.
  deferred_columns = File.expand_path('../deferred_columns', __dir__)
  if File.directory?(deferred_columns)
    gem 'deferred_columns', path: deferred_columns
  else
    # The integration specs need changes that haven't been released on RubyGems yet.
    gem 'deferred_columns', '>= 0.0.2',
      git: 'https://github.com/ElMassimo/deferred_columns.git', ref: '369bde950eb1542ecf51516eeacb4b62c7ff8356'
  end
  gem 'pg' unless ENV.fetch('DATABASE_URL', '').empty?
  gem 'rake', '~> 13.0'
  gem 'rspec', '~> 3.13'
  gem 'simplecov', require: false
  gem 'sqlite3', '>= 2.1'
end
