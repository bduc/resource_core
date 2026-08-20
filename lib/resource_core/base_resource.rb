module ResourceCore
  # The field spec: what a model's attributes are, and how each should be
  # treated. Renderers read it; none of them own it.
  #
  # Apps subclass this once as ApplicationResource and inherit from that, the
  # way ApplicationRecord works — no renderer contributes a base class, because
  # a form base class would be the wrong parent for a table.
  class BaseResource
    class << self
      attr_writer :model_class_name

      def model_class_name
        @model_class_name ||= name&.sub(/#{Regexp.escape(ResourceCore.config.resource_class_suffix)}\z/, "")
      end

      def model_class
        @model_class ||= model_class_name&.safe_constantize
      end

      def fields
        initialize_fields unless @fields
        @fields
      end

      def field(name, options = {})
        initialize_fields
        name = name.to_sym

        if options.nil?
          @fields.delete(name)
        else
          options = options.deep_symbolize_keys
          validate_options!(name, options)
          @fields[name] ||= {}
          @fields[name].merge!(options)
        end
      end

      # Like field, but only for an attribute the detection already found. Used
      # to adjust a detected spec without accidentally inventing a field when
      # the column is renamed away.
      def field!(name, options = {})
        initialize_fields
        name = name.to_sym
        return unless @fields.key?(name)

        if options.nil?
          @fields.delete(name)
        else
          options = options.deep_symbolize_keys
          validate_options!(name, options, current: @fields[name])
          @fields[name].merge!(options)
        end
      end

      def clear_resolution_cache!
        @anonymous = {}
      end

      def anonymous_for(model_class)
        @anonymous ||= {}
        @anonymous[model_class.name] ||= Class.new(ResourceCore.config.base_class).tap do |klass|
          klass.model_class_name = model_class.name
        end
      end

      private

      def initialize_fields
        return if @fields

        @fields = {}
        return unless model_class

        Detection.fields_for(model_class).each { |name, spec| @fields[name] = spec }
      end

      # Raises on an unknown option rather than ignoring it. A silently dropped
      # option looks like the engine ignoring your intent, and is usually a typo.
      def validate_options!(field_name, options, current: nil)
        type_name = options[:as] || current&.dig(:as) || @fields.dig(field_name, :as)
        allowed = Registry.valid_options_for(type_name)

        unknown = options.keys - allowed
        if unknown.any?
          raise ArgumentError,
                "#{self.name || 'resource'}: unknown option(s) #{unknown.inspect} on field " \
                "#{field_name.inspect} (type #{type_name.inspect}). Allowed: #{allowed.sort.inspect}"
        end

        Registry.namespaces.each_key do |namespace|
          value = options[namespace]
          next if value.nil? || value == false

          unless value.is_a?(Hash)
            raise ArgumentError,
                  "#{self.name || 'resource'}: #{field_name.inspect}: #{namespace.inspect} must be a Hash or " \
                  "false, got #{value.class}"
          end

          bad = value.keys - Registry.namespace(namespace)
          next if bad.empty?

          raise ArgumentError,
                "#{self.name || 'resource'}: #{field_name.inspect}: unknown #{namespace.inspect} key(s) " \
                "#{bad.inspect}. Allowed: #{Registry.namespace(namespace).sort.inspect}"
        end
      end
    end
  end
end
