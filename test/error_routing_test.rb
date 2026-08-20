require "test_helper"

class ErrorRoutingTest < ActiveSupport::TestCase
  setup { ResourceCore::Registry.reset! }

  test "a field always consumes its own errors" do
    assert_equal [ :title ], ResourceCore.consumed_error_names(:title, {})
  end

  test "a rule can add one name" do
    ResourceCore.register_error_rule { |name, _spec| name.to_s.sub(/_id\z/, "").to_sym if name.to_s.end_with?("_id") }

    assert_equal %i[author_id author], ResourceCore.consumed_error_names(:author_id, {})
  end

  test "a rule can add several" do
    ResourceCore.register_error_rule { |name, _spec| %i[password_confirmation password_digest] if name == :password }

    assert_equal %i[password password_confirmation password_digest],
                 ResourceCore.consumed_error_names(:password, {})
  end

  test "a rule can read the spec" do
    ResourceCore.register_error_rule { |_name, spec| spec[:mirrors] }

    assert_equal %i[title subtitle], ResourceCore.consumed_error_names(:title, { mirrors: :subtitle })
  end

  test "consume_errors in the spec is honoured alongside the rules" do
    ResourceCore.register_error_rule { |name, _spec| :extra if name == :title }

    assert_equal %i[title extra manual], ResourceCore.consumed_error_names(:title, { consume_errors: :manual })
  end

  test "duplicates collapse" do
    ResourceCore.register_error_rule { |_name, _spec| :title }

    assert_equal [ :title ], ResourceCore.consumed_error_names(:title, {})
  end

  test "a rule returning nil contributes nothing" do
    ResourceCore.register_error_rule { |_name, _spec| nil }

    assert_equal [ :title ], ResourceCore.consumed_error_names(:title, {})
  end

  test "two rules that both match the same field compose additively" do
    ResourceCore.register_error_rule { |name, _spec| :publisher if name == :publisher_id }
    ResourceCore.register_error_rule { |name, _spec| :publisher_name if name == :publisher_id }

    assert_equal %i[publisher_id publisher publisher_name],
                 ResourceCore.consumed_error_names(:publisher_id, {})
  end

  test "a rule that raises contributes nothing but does not block the others" do
    ResourceCore.register_error_rule { |_name, _spec| raise "no such association" }
    ResourceCore.register_error_rule { |name, _spec| :reviewer if name == :review }

    assert_equal %i[review reviewer], ResourceCore.consumed_error_names(:review, {})
  end
end
