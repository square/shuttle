class AssetsKey < ActiveRecord::Base
  belongs_to :asset, inverse_of: :assets_keys
  belongs_to :key, inverse_of: :assets_keys
end
