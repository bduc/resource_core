module ResourceCore
  # A theme and the theme it falls back to.
  #
  # The parent is what makes adopting a renderer incremental: a new theme
  # overrides the partials that differ and inherits the rest, instead of having
  # to supply every one before the first field renders.
  class Theme
    attr_reader :name, :parent

    def initialize(name:, parent: nil)
      @name = name.to_sym
      @parent = parent&.to_sym
    end
  end
end
