# Copyright 2015 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

class AddFilenameToBlobsPrimaryKeyAndRetireCompositePrimaryKeys < ActiveRecord::Migration
  def up
    BlobsCommit.delete_all
    BlobsKey.delete_all
    Blob.delete_all
    ##### REMOVALS

    # HANDLE BLOBS_COMMITS TABLE
    remove_column(:blobs_commits, :project_id)
    remove_column(:blobs_commits, :sha_raw)

    # HANDLE BLOBS_KEYS TABLE
    remove_column(:blobs_keys, :project_id)
    remove_column(:blobs_keys, :sha_raw)

    # HANDLE THE BLOBS TABLE
    # Remove composite primary key
    execute "ALTER TABLE blobs DROP CONSTRAINT blobs_pkey;"
    # This index is unnecessary since we are adding another one below
    remove_index(:blobs, name: :index_blobs_on_project_id_and_sha_raw_and_errored) if index_name_exists?(:blobs, :index_blobs_on_project_id_and_sha_raw_and_errored, false)


    ##### ADDITIONS

    # HANDLE THE BLOBS TABLE
    execute "ALTER TABLE blobs ADD COLUMN id SERIAL PRIMARY KEY"
    # This is the file path + name
    execute "ALTER TABLE blobs ADD COLUMN path text NOT NULL"
    execute "ALTER TABLE blobs ADD COLUMN path_sha_raw bytea NOT NULL"
    add_index(:blobs, [:project_id, :sha_raw, :path_sha_raw], unique: true)
    add_column(:blobs, :created_at, :datetime)
    add_column(:blobs, :updated_at, :datetime)

    # HANDLE BLOBS_COMMITS TABLE
    execute "ALTER TABLE blobs_commits ADD COLUMN id SERIAL PRIMARY KEY"
    add_column(:blobs_commits, :blob_id, :integer, null: false)
    execute "ALTER TABLE blobs_commits ADD CONSTRAINT blobs_commits_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES blobs(id) ON DELETE CASCADE"
    add_index(:blobs_commits, [:blob_id, :commit_id], unique: true)
    add_column(:blobs_commits, :created_at, :datetime)
    add_column(:blobs_commits, :updated_at, :datetime)

    # HANDLE BLOBS_KEYS TABLE
    execute "ALTER TABLE blobs_keys ADD COLUMN id SERIAL PRIMARY KEY"
    add_column(:blobs_keys, :blob_id, :integer, null: false)
    execute "ALTER TABLE blobs_keys ADD CONSTRAINT blobs_keys_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES blobs(id) ON DELETE CASCADE"
    add_index(:blobs_keys, [:blob_id, :key_id], unique: true)
    add_column(:blobs_keys, :created_at, :datetime)
    add_column(:blobs_keys, :updated_at, :datetime)
  end

  def down
    BlobsCommit.delete_all
    BlobsKey.delete_all
    Blob.delete_all

    remove_column(:blobs_commits, :id)
    remove_column(:blobs_commits, :blob_id)
    remove_column(:blobs_commits, :created_at)
    remove_column(:blobs_commits, :updated_at)

    remove_column(:blobs_keys, :id)
    remove_column(:blobs_keys, :blob_id)
    remove_column(:blobs_keys, :created_at)
    remove_column(:blobs_keys, :updated_at)

    remove_column(:blobs, :id)
    remove_column(:blobs, :path)
    remove_column(:blobs, :path_sha_raw)
    remove_column(:blobs, :created_at)
    remove_column(:blobs, :updated_at)


    add_column(:blobs_commits, :project_id, :integer)
    execute "ALTER TABLE blobs_commits ADD COLUMN sha_raw bytea NOT NULL"

    add_column(:blobs_keys, :project_id, :integer)
    execute "ALTER TABLE blobs_keys ADD COLUMN sha_raw bytea NOT NULL"

    execute "ALTER TABLE ONLY blobs ADD CONSTRAINT blobs_pkey PRIMARY KEY (project_id, sha_raw)"
    execute "ALTER TABLE ONLY blobs_commits ADD CONSTRAINT blobs_commits_pkey PRIMARY KEY (project_id, sha_raw, commit_id)"
    execute "ALTER TABLE ONLY blobs_keys ADD CONSTRAINT blobs_keys_pkey PRIMARY KEY (project_id, sha_raw, key_id)"
  end
end
