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

class CommitKeyCreator
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] blob_id The ID of a Blob these Keys were all imported from.
  # @param [Fixnum] commit_id The ID of a {Commit} these Keys will be associated
  #   with.
  # @param [String] importer The identifier for the {Importer::Base} subclass
  #   that imported these keys.
  # @param [Array<Hash>] keys An array of key data.

  def perform(blob_id, commit_id, importer, keys)
    @blob     = Blob.find(blob_id)
    @commit   = Commit.find(commit_id)
    @importer = Importer::Base.find_by_ident(importer)

    key_objects = keys.map do |key|
      key.symbolize_keys!
      key[:options].try! :symbolize_keys!
      add_string key[:key], key[:value], (key[:options] || {})
    end

    key_objects.map(&:id).uniq.each { |k| @blob.blobs_keys.where(key_id: k).find_or_create! }

    self.class.update_key_associations key_objects, @commit
  rescue Git::CommitNotFoundError => err
    @commit.add_import_error(err, "failed in CommitKeyCreator for commit_id #{commit_id} and blob_id #{@blob.id}") if @commit
  end

  # Given a set of keys, bulk-updates their commits-keys associations.
  #
  # @param [Array<Key>] keys A set of Keys to update.
  # @param [Commit] commit A Commit these keys are associated with.

  def self.update_key_associations(keys, commit)
    keys.reject! { |key| skip_key?(key, commit) }
    keys.map(&:id).uniq.each { |k| commit.commits_keys.where(key_id: k).find_or_create! }
  end

  include SidekiqLocking

  private

  def add_string(key, value, options={})
    key = @blob.project.keys.for_key(key).source_copy_matches(value).create_or_update!(
        options.reverse_merge(
            key:                  key,
            source_copy:          value,
            importer:             @importer.ident,
            fencers:              @importer.fencers,
            skip_readiness_hooks: true)
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
