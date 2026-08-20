module ResourceCore
  # Turns an Active Record class into a starting set of field specs. Task 5
  # makes the rules extensible; this is the behaviour ported verbatim from
  # resource_form so the move can be verified before anything changes.
  module Detection
    SKIPPED_COLUMNS = %w[id lock_version created_at updated_at].freeze

    class << self
      def fields_for(ar_model)
        specs = {}

        ar_model.columns.each do |column|
          next if SKIPPED_COLUMNS.include?(column.name)

          specs[column.name.to_sym] = { as: column_field_type(column) }
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
