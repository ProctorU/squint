class Post < ActiveRecord::Base
  include Storext.model
  include Squint

  store_attribute :storext_jsonb_attributes, :jsonb_zip_code, String, default: '90210'
  store_attribute :storext_jsonb_attributes, :jsonb_friend_count, Integer, default: 0
  store_attribute :storext_jsonb_attributes, :jsonb_is_awesome, Integer, default: false
  store_attribute :storext_jsonb_attributes, :jsonb_is_present, Integer, default: nil

  store_attribute :storext_hstore_attributes, :hstore_zip_code, String, default: '90210'
  store_attribute :storext_hstore_attributes, :hstore_friend_count, Integer, default: 0
  store_attribute :storext_hstore_attributes, :hstore_is_awesome, Integer, default: false
  store_attribute :storext_hstore_attributes, :hstore_is_present, Integer, default: nil

end
