class AddJobTypeToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :job_type, :smallint, default: 0, null: false
  end
end
