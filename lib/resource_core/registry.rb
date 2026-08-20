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
      def valid_options_for(field_type_name)
        type = field_type_name && field_type(field_type_name)

        (CORE_OPTIONS +
          renderers.values.flatten +
          (type ? type.options : []) +
          namespaces.keys).uniq
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
