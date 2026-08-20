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

  private

  def resource_for(model, &block)
    Class.new(ResourceCore::BaseResource) do
      self.model_class_name = model.name
      instance_eval(&block)
    end
  end
end
