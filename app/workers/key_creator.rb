# Copyright 2014 Square Inc.
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

# Creates a set of {Key Keys} associated with a single {Blob} and {Commit}, as
# part of an import job. Creates keys and then performs after-save hooks in
# batch.

class KeyCreator
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] project_id The ID of a {Blob}'s {Project} these Keys were
  #   all imported from.
  # @param [Fixnum] sha The SHA of a Blob these Keys were all imported from.
  # @param [String] commit_id The ID of a {Commit} these Keys will be associated
  #   with.
  # @param [String] importer The identifier for the {Importer::Base} subclass
  #   that imported these keys.
  # @param [Array<Hash>] keys An array of key data.

  def perform(project_id, sha, commit_id, importer, keys, shuttle_jid=nil)
    @blob     = Blob.where(project_id: project_id).with_sha(sha).first!
    @commit   = Commit.find(commit_id) if commit_id
    @importer = Importer::Base.find_by_ident(importer)

    key_objects = keys.map do |key|
      key.symbolize_keys!
      key[:options].try! :symbolize_keys!
      add_string key[:key], key[:value], (key[:options] || {})
    end

    key_objects.map(&:id).uniq.each { |k| @blob.blobs_keys.where(key_id: k).find_or_create! }

    if @commit
      self.class.update_key_associations key_objects, @commit
    end

    @blob.remove_worker! shuttle_jid
    @commit.remove_worker! shuttle_jid if @commit
  end

  # Given a set of keys, bulk-updates their commits-keys associations and
  # ElasticSearch `commit_ids` associations.
  #
  # @param [Array<Key>] keys A set of Keys to update.
  # @param [Commit] commit A Commit these keys are associated with.

  def self.update_key_associations(keys, commit)
    keys.reject! { |key| skip_key?(key, commit) }
    keys.map(&:id).uniq.each { |k| commit.commits_keys.where(key_id: k).find_or_create! }

    # key.commits has been changed, need to update associated ES fields
    # load the translations associated with each commit
    keys           = Key.where(id: keys.map(&:id)).includes(:translations)
    # preload commits_keys by loading all possible commit ids
    commits_by_key = CommitsKey.connection.select_rows(CommitsKey.select('commit_id, key_id').where(key_id: keys.map(&:id)).to_sql).inject({}) do |hsh, (cid, key_id)|
      hsh[key_id.to_i] ||= Set.new
      hsh[key_id.to_i] << cid.to_i
      hsh
    end
    # organize them into their keys add add this new commit
    keys.each do |key|
      key.batched_commit_ids = commits_by_key[key.id] || Set.new
      key.batched_commit_ids << commit.id
    end
    # and run the import
    Key.tire.index.import keys
    # now update translations with the keys still having the cached commit ids
    Translation.tire.index.import keys.map(&:translations).flatten
  end

  private

  def add_string(key, value, options={})
    key = @blob.project.keys.for_key(key).source_copy_matches(value).create_or_update!(
        options.reverse_merge(
            key:                  key,
            source_copy:          value,
            importer:             @importer.ident,
            fencers:              @importer.fencers,
            skip_readiness_hooks: true,
            batched_commit_ids:   []) # we'll fill this out later
    )

    # add additional pending translations if necessary
    key.add_pending_translations

    return key
  end

  # Determines if we should skip this key using both the normal key exclusions
  # and the .shuttle.yml key exclusions
  def self.skip_key?(key, commit)
    skip_key_due_to_project_settings?(key, commit.project) || skip_key_due_to_branch_settings?(key, commit)
  end

  def self.skip_key_due_to_project_settings?(key, project)
    project.skip_key?(key.key, project.base_locale)
  end

  def self.skip_key_due_to_branch_settings?(key, commit)
    commit.skip_key?(key.key)
  end
end
