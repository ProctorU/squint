require 'test_helper'

class SearchSemiStructuredDataTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = true

  # Tests that should pass for both jsonb and hstore properties
  [:request_info, :properties].each do |prop_name|
    test "generates SQL for #{prop_name}" do
      sql_string = Post.where(prop_name => { referer: "http://example.com/one" } ).to_sql
      assert_match(/\"posts\".\"#{prop_name}\"-[>]{1,2}\'referer\'/, sql_string)
    end

    test "finds records for #{prop_name} populated" do
      reln = Post.where(prop_name => { referer: "http://example.com/one" } )
      assert_equal 1,reln.count
    end

    test "finds records for #{prop_name} with nil" do
      reln = Post.where(prop_name => { referer: nil } )
      assert_equal 1,reln.count, reln.to_sql
    end

    test "finds records for #{prop_name} missing element that doesn't exist with nil" do
      reln = Post.where(prop_name => { not_there: nil } )
      assert_equal Post.all.count,reln.count, reln.to_sql
    end

    test "Doesn't find records for #{prop_name} missing element that doesn't exist populated" do
      reln = Post.where(prop_name => { not_there: "any value will do" } )
      assert_equal 0,reln.count, reln.to_sql
    end

  end

end
