require "test_helper"

class ValueTest < ActiveSupport::TestCase
  setup do
    ResourceCore::Registry.reset!
    @book = Book.new(title: "Moby Dick", pages: 635, price: 12.5, out_of_print: false)
  end

  test "raw reads the attribute" do
    assert_equal "Moby Dick", ResourceCore::Value.raw(@book, :title)
  end

  test "raw returns nil for an attribute the record does not have" do
    assert_nil ResourceCore::Value.raw(@book, :nonexistent)
  end

  test "display without a format is the value to_s" do
    assert_equal "635", ResourceCore::Value.display(@book, :pages, {})
  end

  test "display of nil is an empty string, not the word nil" do
    assert_equal "", ResourceCore::Value.display(@book, :isbn, {})
  end

  test "a registered format is applied" do
    ResourceCore.register_format(:euro) { |value, _record, _spec| "€ #{'%.2f' % value}" }

    assert_equal "€ 12.50", ResourceCore::Value.display(@book, :price, { format: :euro })
  end

  test "a format receives the record and the spec" do
    ResourceCore.register_format(:titled) { |value, record, spec| "#{spec[:prefix]}#{value} by #{record.author_id.inspect}" }

    assert_equal "» Moby Dick by nil",
                 ResourceCore::Value.display(@book, :title, { format: :titled, prefix: "» " })
  end

  test "a format is not applied to nil" do
    ResourceCore.register_format(:euro) { |value, _record, _spec| "€ #{'%.2f' % value}" }

    assert_equal "", ResourceCore::Value.display(@book, :isbn, { format: :euro })
  end

  test "an unregistered format raises rather than silently rendering raw" do
    error = assert_raises(ArgumentError) { ResourceCore::Value.display(@book, :price, { format: :ghost }) }

    assert_match "ghost", error.message
  end

  test "a callable format is used directly" do
    formatter = ->(value, _record, _spec) { value.upcase }

    assert_equal "MOBY DICK", ResourceCore::Value.display(@book, :title, { format: formatter })
  end
end
