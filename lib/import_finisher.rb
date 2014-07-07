# Contains hooks run by Sidekiq upon completion of an import batch.

class ImportFinisher

  # Run by Sidekiq after an import batch finishes successfully. Unsets the
  # {Commit}'s `loading` flag (thus running post-import hooks), and sets the
  # parsed flag on all associated {Blob Blobs}.

  def on_success(_status, options)
    commit = Commit.find(options['commit_id'])

    # if there were errors, persist them in postgresql and notify people
    handle_import_errors!(commit)

    commit.update! loading: false, import_batch_id: nil

    # commit.blobs.update_all loading: false
    blob_shas = commit.blobs_commits.pluck(:sha_raw)
    Blob.where(project_id: commit.project_id, sha_raw: blob_shas, errored: false).update_all parsed: true

    # the readiness hooks were all disabled, so now we need to go through and
    # calculate readiness and stats.
    CommitStatsRecalculator.new.perform commit.id
  end

  private

  def handle_import_errors!(commit)
    if commit.import_errors_in_redis.present?
      commit.move_import_errors_from_redis_to_sql_db!
      CommitMailer.notify_submitter_of_import_errors(commit).deliver
    end
  end
end
