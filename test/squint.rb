require 'test_helper'

class Squint < ActiveSupport::TestCase
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

    test "finds records for #{prop_name} populated with array" do
      reln = Post.where(prop_name => { referer: ["http://example.com/one", "http://example.com/two" ] } )
      assert_equal 2,reln.count, reln.to_sql
    end

    test "finds records for #{prop_name} populated with array including nil" do
      reln = Post.where(prop_name => { referer: ["http://example.com/one", nil ] } )
      assert_equal 2,reln.count, reln.to_sql
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

  [[:storext_jsonb_attributes,'jsonb'], [:storext_hstore_attributes,'hstore']].each do |prop_name,prefix|
    test "detects present #{prop_name}" do
      reln = Post.where(prop_name => { "#{prefix}_zip_code": 35124 } )
      # puts reln.to_sql
      assert_equal 1,reln.count, reln.to_sql
    end

    test "#{prop_name} is composeable in one where" do
      # get the first matching post
      posts = Post.where(prop_name => { "#{prefix}_zip_code": 90210 })
      # compose with previous query with the id of first post
      reln = Post.where(prop_name => { "#{prefix}_zip_code": 90210 }, id: posts.first.id)
      # puts reln.to_sql
      assert_operator posts.count, :>, 1
      assert_equal 1,reln.count, reln.to_sql
    end

    test "#{prop_name} is composeable in multiple wheres" do
      # get the first matching post
      posts = Post.where(prop_name => { "#{prefix}_zip_code": 90210 })
      # compose with previous query with the id of first post
      reln = Post.where(prop_name => { "#{prefix}_zip_code": 90210 }).where(id: posts.first.id)
      # puts reln.to_sql
      assert posts.count > 1
      assert_equal 1,reln.count, reln.to_sql
    end

    test "detects default #{prop_name}" do
      reln = Post.where(prop_name => { "#{prefix}_zip_code": 90210 } )
      # puts reln.to_sql
      assert_equal Post.all.count - 6,reln.count, reln.to_sql
    end

    test "detects present integer #{prop_name}" do
      reln = Post.where(prop_name => { "#{prefix}_friend_count": 10 } )
      # puts reln.to_sql
      assert_equal 1,reln.count, reln.to_sql
    end

    test "detects default integer #{prop_name}" do
      reln = Post.where(prop_name => { "#{prefix}_friend_count": 0 } )
      # puts reln.to_sql
      assert_equal Post.all.count - 5,reln.count, reln.to_sql
    end

    test "detects default Falseclass #{prop_name}" do
      reln = Post.where(prop_name => { "#{prefix}_is_awesome": false } )
      # puts reln.to_sql
      assert_equal Post.all.count - 1,reln.count, reln.to_sql
    end
  end
end
