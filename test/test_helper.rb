ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("dummy/db/migrate", __dir__) ]
require "rails/test_help"

class ActiveSupport::TestCase
  # Each test that registers into the registry must not leak into the next.
  # See ResourceCore::Registry.reset! (Task 3).
end
