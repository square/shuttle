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
  rescue Git::CommitNotFoundError => err
    commit.add_import_error(err, "failed in CommitImporter for commit_id #{commit_id}")
  end

  include SidekiqLocking

  # Contains hooks run by Sidekiq upon completion of an import batch.

  class Finisher

    # Run by Sidekiq after an import batch finishes successfully. Unsets the
    # {Commit}'s `loading` flag (thus running post-import hooks), and sets the
    # parsed flag on all associated {Blob Blobs}.

    def on_success(_status, options)
      commit = Commit.find(options['commit_id'])

      # mark related blobs as parsed so that we don't parse them again
      mark_not_errored_blobs_as_parsed(commit)

      # the readiness hooks were all disabled, so now we need to go through and calculate keys' readiness.
      # This needs to happen before updating loading to false because there are hooks in CommitObserver
      # which gets fired when loading ends, and it expects keys to reflect correct readiness states.
      Key.batch_recalculate_ready!(commit)

      # finish loading
      commit.update!(loading: false, import_batch_id: nil)

      # the readiness hooks were all disabled, so now we need to go through and calculate commit readiness and stats.
      CommitRecalculator.new.perform commit.id
    end

    private

    def mark_not_errored_blobs_as_parsed(commit)
      # This is done here because we cannot have nested sidekiq batches.
      # If we could nest them, we could create sub-batches for blobs, and set parsed to true at the end of that sub-batch.
      # This would potentially be a performance optimization, too, since we would start using the parsed strings earlier
      # instead of waiting till all blob importers are finished.
      commit.blobs.where(errored: false).update_all parsed: true
    end
  end

end
