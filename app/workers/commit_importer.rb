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

# Calls {Commit#import_strings}.

class CommitImporter
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit.

  def perform(commit_id)
    commit = Commit.find(commit_id)
    commit.import_strings
  rescue Git::CommitNotFoundError
    commit.destroy
  end

  include SidekiqLocking

  # Contains hooks run by Sidekiq upon completion of an import batch.

  class Finisher

    # Run by Sidekiq after an import batch finishes successfully. Unsets the
    # {Commit}'s `loading` flag (thus running post-import hooks), and sets the
    # parsed flag on all associated {Blob Blobs}.

    def on_success(_status, options)
      commit = Commit.find(options['commit_id'])
      already_loaded = commit.loaded_at.present?

      # mark related blobs as parsed so that we don't parse them again
      mark_not_errored_blobs_as_parsed(commit)

      # to eliminate duplicate commits (from things like `git -amend`),
      # we calculate a "fingerprint" for the commit based on it's commits_keys
      # once the fingerprint is set, it will check for duplicates
      # and that will decide if this commit is a duplicate.
      set_fingerprint_find_dupes(commit)

      # the readiness hooks were all disabled, so now we need to go through and calculate keys' readiness.
      # This needs to happen before updating loading to false because there are hooks in CommitObserver
      # which gets fired when loading ends, and it expects keys to reflect correct readiness states.
      Key.batch_recalculate_ready!(commit)

      # finish loading
      commit.update!(loading: false, import_batch_id: nil)

      # records metric only when never loaded before
      if !already_loaded and commit.loaded_at and commit.created_at
        loading_time = commit.loaded_at - commit.created_at
        CustomMetricHelper.record_project_loading_time(commit.project.slug, loading_time)

        active_translations = commit.active_translations.group_by { |t| t.rfc5646_locale }
        locale_to_keys = active_translations.map { |locale, ts| [locale, ts.count] }.to_h
        locale_to_words = active_translations.map { |locale, ts| [locale, ts.map(&:words_count).sum] }.to_h
        CustomMetricHelper.record_project_statistics(commit.project.slug, commit.blobs.count, locale_to_keys, locale_to_words)
      end

      # the readiness hooks were all disabled, so now we need to go through and calculate commit readiness and stats.
      CommitRecalculator.new.perform commit.id

      PostLoadingChecker.launch(commit)
    end

    private

    def mark_not_errored_blobs_as_parsed(commit)
      # This is done here because we cannot have nested sidekiq batches.
      # If we could nest them, we could create sub-batches for blobs, and set parsed to true at the end of that sub-batch.
      # This would potentially be a performance optimization, too, since we would start using the parsed strings earlier
      # instead of waiting till all blob importers are finished.
      commit.blobs.where(errored: false).update_all parsed: true
    end

    def set_fingerprint_find_dupes(commit)
      # When the commit has an existing fingerprint, do not change its fingerprint and the duplicate status.
      # This is important for re-importing duplicated commits or commits with duplicates.
      # • Very first commit --> sets fingerprint and duplicate = false
      # • The following commits with same keys --> sets fingerprint and duplicate = true
      # • Re-import the very first commit --> skips fingerprint (the new fingerprint must be same as old one)
      #   and keeps duplicate = false
      # • Re-import following commits with same keys --> skips fingerprint (the new fingerprint must be same as old one)
      #   and keeps duplicate = true
      if commit.fingerprint.nil?
        commit.fingerprint = Digest::SHA1.hexdigest(commit.commits_keys.order(:key_id).pluck(:key_id).join(','))

        # now that we have a fingerprint, look up others to mark this as a duplicate if the exist
        commit.duplicate = Commit.where(fingerprint: commit.fingerprint).exists?
      end
    end
  end

end
