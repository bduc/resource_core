require "test_helper"

class ThemeTest < ActiveSupport::TestCase
  setup { ResourceCore::Registry.reset! }

  test "a theme with no parent is a chain of one" do
    ResourceCore.register_theme :daisyui

    assert_equal [ :daisyui ], ResourceCore.theme_chain(:daisyui)
  end

  test "a theme resolves through its parent" do
    ResourceCore.register_theme :daisyui
    ResourceCore.register_theme :coreui, parent: :daisyui

    assert_equal [ :coreui, :daisyui ], ResourceCore.theme_chain(:coreui)
  end

  test "chains nest more than one level deep" do
    ResourceCore.register_theme :base
    ResourceCore.register_theme :daisyui, parent: :base
    ResourceCore.register_theme :mira, parent: :daisyui

    assert_equal [ :mira, :daisyui, :base ], ResourceCore.theme_chain(:mira)
  end

  test "an unknown parent raises at registration" do
    error = assert_raises(ArgumentError) { ResourceCore.register_theme :coreui, parent: :ghost }

    assert_match "ghost", error.message
  end

  test "an unregistered theme raises when its chain is asked for" do
    error = assert_raises(ArgumentError) { ResourceCore.theme_chain(:nope) }

    assert_match "nope", error.message
  end

  test "a cycle raises rather than looping forever" do
    ResourceCore.register_theme :a
    ResourceCore.register_theme :b, parent: :a
    # Re-registering :a with :b as its parent closes the loop.
    error = assert_raises(ArgumentError) { ResourceCore.register_theme :a, parent: :b }

    assert_match(/cycle/i, error.message)
  end
end
