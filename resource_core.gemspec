require_relative "lib/resource_core/version"

Gem::Specification.new do |spec|
  spec.name        = "resource_core"
  spec.version     = ResourceCore::VERSION
  spec.authors     = [ "mira" ]
  spec.summary     = "Field specs and extension points shared by resource renderers."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files       = Dir["{app,lib}/**/*", "README.md"]

  spec.add_dependency "rails", ">= 7.0"
end
