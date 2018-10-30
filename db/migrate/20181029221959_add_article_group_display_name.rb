class AddArticleGroupDisplayName < ActiveRecord::Migration
  def change
    add_column :groups, :display_name, :string, limit: 256
  end
end
