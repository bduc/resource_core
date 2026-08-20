require "test_helper"

class BaseResourceTest < ActiveSupport::TestCase
  test "detects string columns as text" do
    assert_equal :text, ResourceCore.resolve(Book).fields[:title][:as]
  end

  test "detects decimal, integer, boolean, date and text columns" do
    fields = ResourceCore.resolve(Book).fields

    assert_equal :numeric,  fields[:price][:as]
    assert_equal :numeric,  fields[:pages][:as]
    assert_equal :boolean,  fields[:out_of_print][:as]
    assert_equal :date,     fields[:published_on][:as]
    assert_equal :textarea, fields[:synopsis][:as]
  end

  test "detects belongs_to as lookup_one and keeps the FK column beside it" do
    fields = ResourceCore.resolve(Book).fields

    assert_equal :lookup_one, fields[:author][:as]
    assert_equal "Author",    fields[:author][:class_name]
    assert_not_nil fields[:author_id]
  end

  test "detects has_many as lookup_many" do
    assert_equal :lookup_many, ResourceCore.resolve(Author).fields[:books][:as]
  end

  test "skips id and timestamps" do
    fields = ResourceCore.resolve(Publisher).fields

    assert_not fields.key?(:id)
    assert_not fields.key?(:created_at)
    assert_not fields.key?(:updated_at)
  end

  test "field overrides a detected spec and field(name, nil) removes it" do
    klass = Class.new(ResourceCore::BaseResource) do
      self.model_class_name = "Book"
      field :synopsis, as: :text
      field :isbn, nil
    end

    assert_equal :text, klass.fields[:synopsis][:as]
    assert_not klass.fields.key?(:isbn)
  end

  test "field! only touches an existing field" do
    klass = Class.new(ResourceCore::BaseResource) do
      self.model_class_name = "Book"
      field! :title, label: "Titel"
      field! :nonexistent, label: "Ignored"
    end

    assert_equal "Titel", klass.fields[:title][:label]
    assert_not klass.fields.key?(:nonexistent)
  end

  test "resolve returns the named resource class when one exists" do
    stub_const("BookResource", Class.new(ResourceCore::BaseResource)) do
      assert_equal BookResource, ResourceCore.resolve(Book)
    end
  end

  test "resolve falls back to an anonymous subclass of the configured base class" do
    resolved = ResourceCore.resolve(Review)

    assert resolved < ResourceCore::BaseResource
    assert_equal "Review", resolved.model_class_name
  end

  private

  # Defines a constant for the duration of the block. resolve caches anonymous
  # classes, so the cache is cleared too — otherwise a later test sees the
  # stub's leftovers.
  def stub_const(name, value)
    Object.const_set(name, value)
    ResourceCore::BaseResource.clear_resolution_cache!
    yield
  ensure
    Object.send(:remove_const, name)
    ResourceCore::BaseResource.clear_resolution_cache!
  end
end
