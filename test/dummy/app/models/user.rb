class User < ActiveRecord::Base
  include Storext.model
  include Squint

  store_attribute :settings, :zip_code, String, default: '90210'
end
