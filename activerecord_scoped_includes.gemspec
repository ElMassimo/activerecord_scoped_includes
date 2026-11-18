# frozen_string_literal: true

require_relative 'lib/active_record/scoped_includes/version'

Gem::Specification.new do |spec|
  spec.name          = 'activerecord_scoped_includes'
  spec.version       = ActiveRecord::ScopedIncludes::VERSION
  spec.authors       = ['Maximo Mussini']
  spec.email         = ['maximomussini@gmail.com']

  spec.summary       = 'Choose the columns an association loads, right where you include it.'
  spec.description   = 'activerecord_scoped_includes lets includes, preload and eager_load take a scope for each association, ' \
                       'to select columns or nest includes without defining another association.'
  spec.homepage      = 'https://github.com/ElMassimo/activerecord_scoped_includes'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.0')

  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir.glob('lib/**/*.rb') + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.2'
end
