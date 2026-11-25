# frozen_string_literal: true

module ActiveRecord
  module ScopedIncludes
    # `eager_load`, and `includes` when it eager loads.
    module JoinDependency
      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      module ClassMethods
        # Turns the associations into a tree, keeping the scope of each association.
        def walk_tree(associations, hash)
          return super unless associations.is_a?(Hash) && associations.each_value.any? { |value| ScopedIncludes.scope?(value) }

          associations.each do |name, value|
            next walk_tree({ name => value }, hash) unless ScopedIncludes.scope?(value)

            children = hash[name] ||= {}
            children.instance_variable_set(:@includes_scope, value)
            walk_tree(ScopedIncludes.nested(value), children)
          end
        end
      end

      # A table joined by `eager_load`.
      module JoinAssociation
        attr_reader :includes_scope

        def includes_scope=(scope)
          @includes_scope = scope.except(:includes, :preload, :eager_load)
        end

        # The columns of the association scope merged with the includes scope, as
        # its SELECT would list them, plus the primary key to tell records apart,
        # and the keys that the associations it includes need.
        def column_names
          includes_scope ? includes_column_names : super
        end

      private

        def includes_column_names
          @includes_column_names ||= begin
            scope = reflection.scope ? reflection.scope_for(base_klass.unscoped).merge(includes_scope) : includes_scope
            keys = [*base_klass.primary_key, *ScopedIncludes.owner_keys(children.map(&:reflection))]
            scope.arel.projections.flat_map { |projection| projected_columns(projection) } | keys
          end
        end

        def projected_columns(projection)
          if projection.is_a?(Arel::Attributes::Attribute) && projection.relation.name == base_klass.table_name
            projection.name == Arel.star ? base_klass.column_names : [projection.name.to_s]
          else
            selected = projection.is_a?(Arel::Attributes::Attribute) ? "#{projection.relation.name}.#{projection.name}" : projection.to_s
            raise ArgumentError, "When eager loading, a scope in includes can only select columns of #{base_klass.table_name}, got: #{selected}"
          end
        end
      end

    private

      def build(associations, base_klass)
        associations.each do |name, children|
          scope = children.instance_variable_get(:@includes_scope)
          reflection = find_reflection(base_klass, name)
          next unless scope.is_a?(Proc) && !reflection.polymorphic?

          # A lambda is only resolved once the model is known, to nest its includes.
          scope = ScopedIncludes.resolve(scope, reflection.klass)
          children.instance_variable_set(:@includes_scope, scope)
          self.class.walk_tree(ScopedIncludes.nested(scope), children)
        end

        super.each_with_index do |join, index|
          scope = associations.values[index].instance_variable_get(:@includes_scope)
          join.includes_scope = ScopedIncludes.resolve(scope, join.base_klass) if scope
        end
      end
    end
  end
end
