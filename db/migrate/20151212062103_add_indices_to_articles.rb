class AddIndicesToArticles < ActiveRecord::Migration
  def change
    add_index :articles, :ready
    add_index :articles, :name_sha_raw
  end
end
