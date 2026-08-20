module ResourceCore
  # Turns an Active Record class into a starting set of field specs. Detection
  # is a prependable chain: registered detectors run newest-first, and the
  # column-type mapping is the floor an app or engine can never fail to hit.
  module Detection
    SKIPPED_COLUMNS = %w[id lock_version created_at updated_at].freeze

    class << self
      def fields_for(ar_model)
        specs = {}

        ar_model.columns.each do |column|
          next if SKIPPED_COLUMNS.include?(column.name)

          name = column.name.to_sym
          specs[name] = { as: field_type_for(name, column) }
        end

        ar_model.reflect_on_all_associations.each do |assoc|
          case assoc.macro
          when :belongs_to
            # Both :author (association) and :author_id (column) stay available:
            # one renders as a lookup, the other as a plain select.
            specs[assoc.name] = {
              as: :lookup_one,
              class_name: assoc.class_name,
              polymorphic: !!assoc.polymorphic?
            }
          when :has_many
            specs[assoc.name] = { as: :lookup_many, class_name: assoc.class_name }
          end
        end

        specs
      end

      # Registered detectors first, newest to oldest; the column-type mapping is
      # the floor, so there is always an answer.
      def field_type_for(name, column)
        Registry.detectors.each do |detector|
          result = detector.call(name, column)
          return result.to_sym if result
        end

        column ? column_field_type(column) : :text
      end

      def column_field_type(column)
        case column.type
        when :string then :text
        when :text then :textarea
        when :integer, :bigint, :decimal, :float then :numeric
        when :boolean then :boolean
        when :date then :date
        when :datetime, :timestamp then :datetime
        else :text
        end
      end
    end
  end
end
