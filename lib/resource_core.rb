require "resource_core/version"
require "resource_core/configuration"
require "resource_core/engine"
require "resource_core/detection"
require "resource_core/base_resource"
require "resource_core/field_type"
require "resource_core/theme"
require "resource_core/registry"

module ResourceCore
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def register_renderer(name, options: [])
      Registry.register_renderer(name, options: options)
    end

    def register_field_type(name, renderers:, **rest)
      Registry.register_field_type(name, renderers: renderers, **rest)
    end

    def field_type(name)
      Registry.field_type(name)
    end

    def register_namespace(name, options)
      Registry.register_namespace(name, options)
    end

    def detect(&block)
      Registry.register_detector(&block)
    end

    def field_types(renderer: nil)
      Registry.field_types_for(renderer)
    end

    def register_theme(name, parent: nil)
      Registry.register_theme(name, parent: parent)
    end

    def theme_chain(name)
      Registry.theme_chain(name)
    end

    def register_error_rule(&block)
      Registry.register_error_rule(&block)
    end

    def consumed_error_names(name, spec)
      Registry.consumed_error_names(name, spec)
    end

    # Human-readable label for a record already selected in a lookup field.
    # `label_method` (from the field spec) takes precedence over the
    # conventional readers in `config.lookup_label_methods`; `to_s` is the last
    # resort so a model that declares none of them still renders.
    def lookup_label(record, label_method: nil)
      return nil if record.nil?

      candidates = [ label_method, *config.lookup_label_methods ].compact
      match = candidates.find do |reader|
        record.respond_to?(reader) && record.public_send(reader).presence
      end

      match ? record.public_send(match).to_s : record.to_s
    end

    # The resource class describing `model_class`: the conventionally named one
    # if it exists, else an anonymous subclass of the app's base class so
    # detected fields still carry the app's conventions.
    def resolve(model_class)
      suffix = config.resource_class_suffix
      if suffix
        named = "#{model_class.name}#{suffix}".safe_constantize
        return named if named && named < ResourceCore::BaseResource
      end

      ResourceCore::BaseResource.anonymous_for(model_class)
    end
  end
end
