$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "search_semi_structured_data/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "search_semi_structured_data"
  s.version     = SearchSemiStructuredData::VERSION
  s.authors     = ["David H. Wilkins"]
  s.email       = ["dwilkins@proctoru.com"]
  s.homepage    = "http://proctoru.com"
  s.summary     = "Search jsonb and hstore columns"
  s.description = "Use rails semantics to search jsonb and hstore columns"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.8"

  s.add_development_dependency "pg"
end
