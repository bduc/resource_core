require "test_helper"

class FieldOptionsTest < ActiveSupport::TestCase
  setup do
    ResourceCore::Registry.reset!
    ResourceCore.register_renderer :form, options: %i[placeholder required]
    ResourceCore.register_field_type :text, renderers: [ :form ]
    ResourceCore.register_field_type :rich_text, renderers: [ :form ], options: %i[toolbar]
    ResourceCore.register_namespace :index, %i[sortable width]
  end

  test "core options are always allowed" do
    klass = resource_for(Book) { field :title, as: :text, label: "Titel", hint: "…" }

    assert_equal "Titel", klass.fields[:title][:label]
  end

  test "a renderer's shared options are allowed on any of its types" do
    klass = resource_for(Book) { field :title, as: :text, placeholder: "Moby Dick" }

    assert_equal "Moby Dick", klass.fields[:title][:placeholder]
  end

  test "a type's own options are allowed only on that type" do
    klass = resource_for(Book) { field :synopsis, as: :rich_text, toolbar: %i[bold] }
    assert_equal %i[bold], klass.fields[:synopsis][:toolbar]

    error = assert_raises(ArgumentError) do
      resource_for(Book) { field :title, as: :text, toolbar: %i[bold] }
    end
    assert_match "toolbar", error.message
    assert_match "text", error.message
  end

  test "an unknown option raises and names what was allowed" do
    error = assert_raises(ArgumentError) do
      resource_for(Book) { field :title, as: :text, plaseholder: "typo" }
    end

    assert_match "plaseholder", error.message
    assert_match "placeholder", error.message
  end

  test "a registered namespace accepts a hash of its own keys" do
    klass = resource_for(Book) { field :title, as: :text, index: { sortable: true, width: 180 } }

    assert_equal({ sortable: true, width: 180 }, klass.fields[:title][:index])
  end

  test "a namespace accepts false, meaning excluded from that renderer" do
    klass = resource_for(Book) { field :synopsis, as: :rich_text, index: false }

    assert_equal false, klass.fields[:synopsis][:index]
  end

  test "an unknown key inside a namespace raises" do
    error = assert_raises(ArgumentError) do
      resource_for(Book) { field :title, as: :text, index: { sortabel: true } }
    end

    assert_match "sortabel", error.message
    assert_match "index", error.message
  end

  test "an unregistered namespace is just an unknown option" do
    error = assert_raises(ArgumentError) do
      resource_for(Book) { field :title, as: :text, kanban: { lane: 1 } }
    end

    assert_match "kanban", error.message
  end

  test "field! rejects an option belonging to a different type than the one already stored" do
    ResourceCore.register_field_type :money, renderers: [ :form ], options: %i[currency]

    klass = resource_for(Book) { field :synopsis, as: :rich_text, toolbar: %i[bold] }

    error = assert_raises(ArgumentError) do
      klass.field! :synopsis, currency: "EUR"
    end
    assert_match "currency", error.message

    # Still resolves to :rich_text, not to "no type at all": its own option
    # keeps working right after the rejection above.
    klass.field! :synopsis, toolbar: %i[italic]
    assert_equal %i[italic], klass.fields[:synopsis][:toolbar]
  end

  test "field! validates a repeated option against the stored type when as: is not repeated" do
    klass = resource_for(Book) { field :synopsis, as: :rich_text, toolbar: %i[bold] }

    klass.field! :synopsis, toolbar: %i[italic]

    assert_equal %i[italic], klass.fields[:synopsis][:toolbar]
  end

  test "field! changing the type via as: validates against the new type, not the old one" do
    ResourceCore.register_field_type :money, renderers: [ :form ], options: %i[currency]

    klass = resource_for(Book) { field :price, as: :money, currency: "EUR" }

    klass.field! :price, as: :rich_text, toolbar: %i[bold]
    assert_equal :rich_text, klass.fields[:price][:as]
    assert_equal %i[bold], klass.fields[:price][:toolbar]

    # Switching back: toolbar belonged to the type just left behind, and must
    # not be grandfathered in against the newly-named type.
    error = assert_raises(ArgumentError) do
      klass.field! :price, as: :money, toolbar: %i[bold]
    end
    assert_match "toolbar", error.message
  end

  private

  def resource_for(model, &block)
    Class.new(ResourceCore::BaseResource) do
      self.model_class_name = model.name
      instance_eval(&block)
    end
  end
end
