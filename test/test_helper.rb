# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb",  __FILE__)
ActiveRecord::Migrator.migrations_paths =
  [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
require "rails/test_help"

require 'minitest/focus'
# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../dummy/test/fixtures", __FILE__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.fixtures :all
end

class ActiveSupport::TestCase
  fixtures :all
  # 'cuz I want to be able to login to the db and see things
  # and there aren't many tests here anyway, so speed isn't a problem
  if ActiveRecord::VERSION::STRING < '5'
    self.use_transactional_fixtures = false
  elsif ActiveRecord::VERSION::STRING > '5'
    self.use_transactional_tests = false
  end
end
