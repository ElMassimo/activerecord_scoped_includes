# frozen_string_literal: true

# The main Gemfile, with its paths relative to this folder.
def main_gemfile
  File.read(File.expand_path('../Gemfile', __dir__))
    .sub('gemspec', 'gemspec path: ".."')
    .sub("path: '../deferred_columns'", "path: '../../deferred_columns'")
end
