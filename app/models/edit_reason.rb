class EditReason < ActiveRecord::Base
  belongs_to :reason
  belongs_to :translation_change
end
