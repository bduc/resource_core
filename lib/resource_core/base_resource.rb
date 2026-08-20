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
          @fields[name] ||= {}
          @fields[name].merge!(options.deep_symbolize_keys)
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
          @fields[name].merge!(options.deep_symbolize_keys)
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
    end
  end
end
