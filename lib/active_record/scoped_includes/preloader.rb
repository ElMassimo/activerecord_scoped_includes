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
            scope = shape_of(resolved_includes_scope(@includes_reflection.klass))
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

        # A lambda is only resolved once the model is known, so the associations it
        # includes become children when its records are about to load.
        def children
          return super unless @includes_scope.is_a?(Proc) && @loaders && !@nested

          @nested = true
          @includes_reflection = nil # so that the children get the scope of the preloader
          @children = build_children(@resolved_includes_scopes.to_h.values.flat_map { |scope| ScopedIncludes.nested(scope) })
        end

        # Remembers the reflection, since each target model resolves the scope separately.
        def preloaders_for_reflection(reflection, records)
          @includes_reflection = reflection
          super
        end

      private

        def resolved_includes_scope(model)
          (@resolved_includes_scopes ||= {})[model] ||= ScopedIncludes.resolve(@includes_scope, model)
        end

        # The scope without its includes, selecting the keys they need to load.
        def shape_of(scope)
          names = ScopedIncludes.nested(scope).flat_map { |nested| nested.is_a?(Hash) ? nested.keys : nested }
          keys = ScopedIncludes.owner_keys(names.filter_map { |name| scope.klass._reflect_on_association(name) })
          keys -= scope.select_values.map(&:to_s)
          scope = scope.except(:includes, :preload, :eager_load)
          scope.select_values.any? && keys.any? ? scope.select(*keys) : scope
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
