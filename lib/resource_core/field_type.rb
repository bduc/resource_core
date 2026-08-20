module ResourceCore
  # One registered field type. Declaring a type is how a renderer — or an app —
  # adds a way of rendering a field, instead of relying on `as:` being
  # interpolated into a partial path and failing at render time on a typo.
  class FieldType
    attr_reader :name, :renderers, :options, :defaults, :partial

    def initialize(name:, renderers:, options: [], defaults: {}, partial: nil, wrapper: true)
      @name = name.to_sym
      @renderers = Array(renderers).map(&:to_sym)
      @options = Array(options).map(&:to_sym)
      @defaults = defaults.to_h.symbolize_keys
      # Defaults to the type's own name: the common case is one partial per
      # type, named after it.
      @partial = (partial || @name).to_s
      @wrapper = wrapper
    end

    # False for types that render their own label — a checkbox puts it inside
    # the control, so the shared wrapper would emit a second one.
    def wrapper?
      !!@wrapper
    end

    def renders_for?(renderer)
      @renderers.include?(renderer.to_sym)
    end
  end
end
