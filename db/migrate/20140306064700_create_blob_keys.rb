class CreateBlobKeys < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE blobs_keys (
        project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        sha_raw bytea NOT NULL,
        key_id INTEGER NOT NULL REFERENCES keys(id) ON DELETE CASCADE,
        FOREIGN KEY (project_id, sha_raw) REFERENCES blobs(project_id, sha_raw) ON DELETE CASCADE,
        PRIMARY KEY (project_id, sha_raw, key_id)
      )
    SQL

    execute "ALTER TABLE blobs ADD keys_cached BOOLEAN NOT NULL DEFAULT FALSE"
  end

  def down
    execute "ALTER TABLE blobs DROP keys_cached"

    drop_table :blobs_keys
  end
end
