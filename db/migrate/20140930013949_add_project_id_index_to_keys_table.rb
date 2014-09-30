class AddProjectIdIndexToKeysTable < ActiveRecord::Migration
  def change
    add_index :keys, :project_id
  end
end
