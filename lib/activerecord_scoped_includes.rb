# frozen_string_literal: true

require 'active_record'
require 'active_record/scoped_includes/version'

module ActiveRecord
  # Lets `includes`, `preload` and `eager_load` take a scope as the value of an
  # association, to choose the columns it loads and the associations it includes.
  #
  #   Album.includes(songs: -> { select(:id, :name) })
  #   Album.preload(songs: Song.with_deferred(:lyrics).includes(:playlist_entries))
  #
  # The records still load into the association itself, so code reading
  # `album.songs` gets them without a second association that loads them again.
  module ScopedIncludes
    # The parts of a scope that change how each record is loaded, but not which
    # records are, so the association always holds all of its records.
    SHAPE_VALUES = %i[select extending includes preload eager_load strict_loading].freeze

    # Whether the value of an association in `includes` is a scope.
    def self.scope?(value)
      value.is_a?(ActiveRecord::Relation) || value.is_a?(Proc)
    end

    # The relation for a scope, which can be a relation or a lambda evaluated on
    # the model, as in association scopes.
    def self.resolve(scope, model)
      scope = model.unscoped.instance_exec(&scope) if scope.is_a?(Proc)
      unsupported = scope.values.keys - SHAPE_VALUES
      return scope if unsupported.empty?

      raise ArgumentError,
        "A scope in includes can only select columns or include associations, but this one uses #{unsupported.join(', ')}. " \
        'To load only some of the records, define an association with that scope instead.'
    end

    # The associations a scope includes, which become the children of its association.
    def self.nested(scope)
      return [] unless scope.is_a?(ActiveRecord::Relation)

      [*scope.includes_values, *scope.preload_values, *scope.eager_load_values]
    end

    # The columns of their owner that the associations need to load their records,
    # such as the foreign key of a `belongs_to`.
    def self.owner_keys(reflections)
      reflections.flat_map { |reflection|
        link = reflection
        link = link.through_reflection while link.through_reflection?
        link.belongs_to? ? [*link.foreign_key, *(link.foreign_type if link.polymorphic?)] : [*link.active_record_primary_key]
      }.map(&:to_s).uniq
    end
  end
end

require 'active_record/scoped_includes/preloader'
require 'active_record/scoped_includes/join_dependency'

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Associations::Preloader::Branch.prepend(ActiveRecord::ScopedIncludes::Preloader::Branch)
  ActiveRecord::Associations::Preloader::Association.prepend(ActiveRecord::ScopedIncludes::Preloader::Association)
  ActiveRecord::Associations::JoinDependency.prepend(ActiveRecord::ScopedIncludes::JoinDependency)
  ActiveRecord::Associations::JoinDependency::JoinAssociation.prepend(ActiveRecord::ScopedIncludes::JoinDependency::JoinAssociation)
end
