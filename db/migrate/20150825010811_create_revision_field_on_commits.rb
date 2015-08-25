class CreateRevisionFieldOnCommits < ActiveRecord::Migration
  def change
    add_column :commits, :revision, :string, limit: 40

    Commit.define_singleton_method(:readonly_attributes) { [] }
    Commit.find_each do |commit|
      commit.update! revision: commit.revision_raw.unpack('H*').first
    end
    change_column_null :commits, :revision, false

    add_index :commits, [:project_id, :revision], unique: true
    remove_column :commits, :revision_raw
  end
end
