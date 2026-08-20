module ResourceCore
  # Reading an attribute and turning it into something displayable.
  #
  # Here rather than in a renderer because every renderer needs it, and two
  # implementations of `format: :currency` would mean two different currencies
  # within a year.
  module Value
    class << self
      def raw(record, name)
        return nil unless record.respond_to?(name)

        record.public_send(name)
      end

      def display(record, name, spec = {})
        value = raw(record, name)
        formatter = (spec || {})[:format]

        # nil formats to nothing whatever the format says: a formatter written
        # for a number should never be handed nil to interpolate.
        return "" if value.nil?
        return value.to_s if formatter.nil?

        resolve_format(formatter).call(value, record, spec || {}).to_s
      end

      private

      def resolve_format(formatter)
        return formatter if formatter.respond_to?(:call)

        Registry.formats[formatter.to_sym] ||
          raise(ArgumentError,
                "unknown format #{formatter.inspect}. Register it with " \
                "ResourceCore.register_format, or pass a callable.")
      end
    end
  end
end
