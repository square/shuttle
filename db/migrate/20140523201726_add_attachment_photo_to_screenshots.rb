class AddAttachmentPhotoToScreenshots < ActiveRecord::Migration
  def self.up
    change_table :screenshots do |t|
      t.attachment :image
    end
  end

  def self.down
    drop_attached_file :screenshots, :image
  end
end
