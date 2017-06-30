$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "squint/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "squint"
  s.version     = Squint::VERSION
  s.authors     = ["David H. Wilkins"]
  s.email       = ["dwilkins@proctoru.com"]
  s.homepage    = "https://github.com/ProctorU/squint"
  s.summary     = "Search PostgreSQL jsonb and hstore columns"
  s.description = "Use rails semantics to search keys and values inside " \
                  "PostgreSQL jsonb, json and hstore columns.  Compatible " \
                  "with StoreXT attributes."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.8"
  s.add_dependency "pg"
end
