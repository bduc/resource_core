require "test_helper"

class RegistryTest < ActiveSupport::TestCase
  setup { ResourceCore::Registry.reset! }
  teardown { ResourceCore::Registry.reset! }

  test "a registered type is retrievable and defaults its partial to its name" do
    ResourceCore.register_renderer :form
    ResourceCore.register_field_type :rich_text, renderers: [ :form ]

    type = ResourceCore.field_type(:rich_text)

    assert_equal :rich_text, type.name
    assert_equal "rich_text", type.partial
    assert type.wrapper?
  end

  test "a type can carry its own options, defaults and partial" do
    ResourceCore.register_renderer :form
    ResourceCore.register_field_type :rich_text,
                                     renderers: [ :form ],
                                     options: %i[toolbar rows],
                                     defaults: { rows: 6 },
                                     partial: "editor",
                                     wrapper: false

    type = ResourceCore.field_type(:rich_text)

    assert_equal %i[toolbar rows], type.options
    assert_equal({ rows: 6 }, type.defaults)
    assert_equal "editor", type.partial
    assert_not type.wrapper?
  end

  test "an unknown field type is nil rather than an error object" do
    assert_nil ResourceCore.field_type(:nope)
  end

  test "registering for an unknown renderer raises at registration" do
    error = assert_raises(ArgumentError) do
      ResourceCore.register_field_type :rich_text, renderers: [ :ghost ]
    end

    assert_match "ghost", error.message
  end

  test "field_types can be filtered by renderer" do
    ResourceCore.register_renderer :form
    ResourceCore.register_renderer :table
    ResourceCore.register_field_type :text, renderers: [ :form, :table ]
    ResourceCore.register_field_type :rich_text, renderers: [ :form ]

    assert_equal %i[text rich_text].sort, ResourceCore.field_types(renderer: :form).keys.sort
    assert_equal %i[text], ResourceCore.field_types(renderer: :table).keys
  end

  test "re-registering the same name replaces it, so an app can override an engine type" do
    ResourceCore.register_renderer :form
    ResourceCore.register_field_type :text, renderers: [ :form ], defaults: { rows: 1 }
    ResourceCore.register_field_type :text, renderers: [ :form ], defaults: { rows: 9 }

    assert_equal({ rows: 9 }, ResourceCore.field_type(:text).defaults)
  end

  test "mutating the hash returned by field_types cannot corrupt the registry" do
    ResourceCore.register_renderer :form
    ResourceCore.register_field_type :text, renderers: [ :form ]

    ResourceCore.field_types[:hacked] = :oops

    assert_nil ResourceCore.field_type(:hacked)
    assert_equal %i[text], ResourceCore.field_types.keys
  end
end
