module ResourceCore
  # Everything a renderer or an app can add to the engine, in one place: field
  # types, the renderers they belong to, the option namespaces each renderer
  # validates, themes, detectors, error rules and formats.
  #
  # Registration happens at boot, so a typo raises then rather than at render
  # time in whichever view happens to use it.
  module Registry
    class << self
      def reset!
        @renderers = {}
        @field_types = {}
        @namespaces = {}
        @themes = {}
        @detectors = []
        @error_rules = []
        @formats = {}
      end

      def renderers
        @renderers ||= {}
      end

      def field_types
        @field_types ||= {}
      end

      def namespaces
        @namespaces ||= {}
      end

      def themes
        @themes ||= {}
      end

      def detectors
        @detectors ||= []
      end

      def error_rules
        @error_rules ||= []
      end

      def formats
        @formats ||= {}
      end

      def register_renderer(name, options: [])
        renderers[name.to_sym] = Array(options).map(&:to_sym)
      end

      def register_field_type(name, renderers:, **rest)
        unknown = Array(renderers).map(&:to_sym) - self.renderers.keys
        if unknown.any?
          raise ArgumentError,
                "field type #{name.inspect} names unregistered renderer(s) #{unknown.inspect}. " \
                "Register the renderer first with ResourceCore.register_renderer."
        end

        field_types[name.to_sym] = FieldType.new(name: name, renderers: renderers, **rest)
      end

      def field_type(name)
        field_types[name.to_sym]
      end

      def field_types_for(renderer)
        return field_types.dup if renderer.nil?

        field_types.select { |_name, type| type.renders_for?(renderer) }
      end

      def register_namespace(name, options)
        namespaces[name.to_sym] = Array(options).map(&:to_sym)
      end

      # Newest first: an app registers after the engines, and should win.
      def register_detector(&block)
        detectors.unshift(block)
      end

      def namespace(name)
        namespaces[name.to_sym]
      end

      # Every option key a field of this type may carry: the spec's own, every
      # registered renderer's shared set, the type's own, and the names of the
      # registered namespaces.
      #
      # A nil type_name (a field declared before any type is registered)
      # yields the core options alone — which must still include :as, or
      # declaring a field at all becomes impossible.
      #
      # A type_name that names no registered type (a typo'd `as:`, or one
      # whose registration hasn't run yet) hits the same fallback: `type`
      # ends up nil either way, so the permissive core-options set applies
      # and the bad type name itself is never flagged here.
      def valid_options_for(field_type_name)
        type = field_type_name && field_type(field_type_name)

        (CORE_OPTIONS +
          renderers.values.flatten +
          (type ? type.options : []) +
          namespaces.keys).uniq
      end

      def register_theme(name, parent: nil)
        name = name.to_sym
        parent = parent&.to_sym

        if parent && !themes.key?(parent)
          raise ArgumentError,
                "theme #{name.inspect} names unknown parent #{parent.inspect}. Register the parent first."
        end

        candidate = Theme.new(name: name, parent: parent)
        detect_cycle!(name, candidate)
        themes[name] = candidate
      end

      # The theme, then its ancestors. A renderer walks this and uses the first
      # partial that exists.
      def theme_chain(name)
        name = name.to_sym
        raise ArgumentError, "unregistered theme #{name.inspect}" unless themes.key?(name)

        chain = []
        current = themes[name]
        while current
          chain << current.name
          current = current.parent && themes[current.parent]
        end
        chain
      end

      def register_error_rule(&block)
        error_rules << block
      end

      # Which attributes a field reports errors for. Always itself, plus
      # whatever the registered rules and the spec's own consume_errors add —
      # so an FK field can surface the association's error, and nothing is
      # silently unreported.
      def consumed_error_names(name, spec)
        name = name.to_sym
        from_rules = error_rules.flat_map { |rule| Array(rule.call(name, spec || {})) }
        explicit = Array((spec || {})[:consume_errors])

        ([ name ] + from_rules + explicit).compact.map(&:to_sym).uniq
      end

      private

      # Walks the prospective chain before storing it, so a loop is refused at
      # registration rather than hanging the first render.
      def detect_cycle!(name, candidate)
        seen = [ name ]
        parent = candidate.parent

        while parent
          raise ArgumentError, "theme #{name.inspect} would create a parent cycle: #{(seen + [ parent ]).inspect}" if seen.include?(parent)

          seen << parent
          parent = themes[parent]&.parent
        end
      end
    end

    # Options every field accepts, whatever its type. These belong to the spec
    # itself rather than to any one way of rendering it.
    #
    # Defined on the module, not inside `class << self` — a constant declared
    # in the singleton class lands on the singleton and `Registry::CORE_OPTIONS`
    # would not resolve from outside.
    CORE_OPTIONS = %i[
      as label hint partial format unit consume_errors class_name polymorphic
    ].freeze
  end
end
