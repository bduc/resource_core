require "test_helper"

class DetectionTest < ActiveSupport::TestCase
  setup { ResourceCore::Registry.reset! }

  test "falls back to the column type when no detector matches" do
    assert_equal :text, ResourceCore::Detection.field_type_for(:title, column_for(Book, "title"))
    assert_equal :numeric, ResourceCore::Detection.field_type_for(:pages, column_for(Book, "pages"))
  end

  test "a registered detector wins over the column type" do
    ResourceCore.detect { |name, _column| :email if name.to_s.include?("email") }

    assert_equal :email, ResourceCore::Detection.field_type_for(:contact_email, column_for(Book, "isbn"))
  end

  test "the most recently registered detector wins, so an app can override an engine rule" do
    ResourceCore.detect { |name, _column| :text if name == :isbn }
    ResourceCore.detect { |name, _column| :barcode if name == :isbn }

    assert_equal :barcode, ResourceCore::Detection.field_type_for(:isbn, column_for(Book, "isbn"))
  end

  test "a detector returning nil defers to the next one" do
    ResourceCore.detect { |_name, _column| nil }

    assert_equal :date, ResourceCore::Detection.field_type_for(:published_on, column_for(Book, "published_on"))
  end

  test "a detector can inspect the column, not just the name" do
    ResourceCore.detect { |_name, column| :json if column&.type == :jsonb }

    assert_equal :json, ResourceCore::Detection.field_type_for(:metadata, column_for(Book, "metadata"))
  end

  test "detectors apply to whole-model detection" do
    ResourceCore.detect { |name, _column| :isbn_field if name == :isbn }

    assert_equal :isbn_field, ResourceCore::Detection.fields_for(Book)[:isbn][:as]
  end

  private

  def column_for(model, name)
    model.columns.find { |c| c.name == name }
  end
end
