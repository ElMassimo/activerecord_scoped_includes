# frozen_string_literal: true

module ActiveRecord
  module ScopedIncludes
    # `preload`, and `includes` when it doesn't eager load.
    module Preloader
      # A node in the tree of associations to preload.
      module Branch
        # Takes the scope out of the children, which become the associations it includes.
        def initialize(association:, children:, parent:, associate_by_default:, scope:)
          includes_scope = children if ScopedIncludes.scope?(children)
          children = ScopedIncludes.nested(includes_scope) if includes_scope
          super # with the reassigned children
          @includes_scope = includes_scope
        end

        # The scope of each loader, which applies on top of the association scope.
        def scope
          return super unless @includes_scope && @includes_reflection

          (@includes_scopes ||= {})[@includes_reflection] ||= begin
            scope = ScopedIncludes.resolve(@includes_scope, @includes_reflection.klass).except(:includes, :preload, :eager_load)
            preload_scope = super
            if preload_scope.is_a?(ActiveRecord::Relation)
              preload_scope.merge(scope)
            elsif preload_scope&.strict_loading_value
              scope.strict_loading
            else
              scope
            end
          end
        end

        # Remembers the reflection, since each target model resolves the scope separately.
        def preloaders_for_reflection(reflection, records)
          @includes_reflection = reflection
          super
        end
      end

      # Loads the records of an association.
      module Association
      private

        # A scope that selects columns still needs the keys that link each record to its owner.
        def build_scope
          scope = super
          # Through loaders pass their scope on to the loaders of the source association.
          return scope if scope.select_values.empty? || is_a?(ActiveRecord::Associations::Preloader::ThroughAssociation)

          key = respond_to?(:destination_key_name, true) ? destination_key_name : association_key_name # renamed in Rails 8.2
          keys = [*key, *klass.primary_key].map(&:to_s) - scope.select_values.map(&:to_s)
          keys.any? ? scope.select(*keys) : scope
        end
      end
    end
  end
end
