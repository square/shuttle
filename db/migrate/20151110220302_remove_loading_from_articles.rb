class RemoveLoadingFromArticles < ActiveRecord::Migration
  def change
    remove_column :articles, :loading
  end
end
