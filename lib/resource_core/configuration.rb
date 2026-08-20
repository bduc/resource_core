module ResourceCore
  class Configuration
    attr_accessor :theme, :resource_class_suffix, :lookup_label_methods
    attr_writer :base_class

    def initialize
      @theme = :daisyui
      @resource_class_suffix = "Resource"
      # Readers tried, in order, to label an already-selected lookup record.
      # A field can override this with `label_method:`.
      @lookup_label_methods = %i[lookup_label display_name full_name name]
      # Held as a String and constantized on demand: the app class it names is
      # reloadable in development, so a captured constant would go stale.
      @base_class_name = "ApplicationResource"
    end

    def base_class=(value)
      @base_class_name = value.to_s
    end

    def base_class
      @base_class_name.safe_constantize || ResourceCore::BaseResource
    end
  end
end
