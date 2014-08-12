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

# Contains hooks run by Sidekiq upon completion of an import batch.

class ImportFinisher

  # Run by Sidekiq after an import batch finishes successfully. Unsets the
  # {Commit}'s `loading` flag (thus running post-import hooks), and sets the
  # parsed flag on all associated {Blob Blobs}.

  def on_success(_status, options)
    commit = Commit.find(options['commit_id'])

    # if there were errors, persist them in postgresql and notify people
    handle_import_errors!(commit)

    # finish loading
    commit.update! loading: false, import_batch_id: nil

    # mark related blobs as parsed so that we don't parse them again
    mark_not_errored_blobs_as_parsed(commit)

    # the readiness hooks were all disabled, so now we need to go through and
    # calculate readiness and stats.
    CommitStatsRecalculator.new.perform commit.id
  end

  private

  # if there were errors, persist them in postgresql and notify people
  def handle_import_errors!(commit)
    if commit.import_errors_in_redis.present?
      commit.move_import_errors_from_redis_to_sql_db!
      CommitMailer.notify_submitter_of_import_errors(commit).deliver
    end
  end

  def mark_not_errored_blobs_as_parsed(commit)
    # This is done here because we cannot have nested sidekiq batches.
    # If we could nest them, we could create sub-batches for blobs, and set parsed to true at the end of that sub-batch.
    # This would potentially be a performance optimization, too, since we would start using the parsed strings earlier
    # instead of waiting till all blob importers are finished.

    # commit.blobs.where(errored: false).update_all parsed: true
    blob_shas = commit.blobs_commits.pluck(:sha_raw)
    Blob.where(project_id: commit.project_id, sha_raw: blob_shas, errored: false).update_all parsed: true
  end
end
