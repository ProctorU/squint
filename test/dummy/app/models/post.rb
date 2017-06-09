class Post < ActiveRecord::Base
  include Storext.model
  include SearchSemiStructuredData

  store_attribute :storext_attributes, :zip_code, String, default: '90210'
  store_attribute :storext_attributes, :friend_count, Integer, default: 0

end
