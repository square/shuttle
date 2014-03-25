# Contains hooks run by Sidekiq upon completion of an import batch.

class ImportFinisher

  # Run by Sidekiq after an import batch finishes successfully. Unsets the
  # {Commit}'s `loading` flag (thus running post-import hooks), and unsets the
  # loading flag on all associated {Blob Blobs}.

  def on_success(_status, options)
    commit = Commit.find(options['commit_id'])
    commit.update_attributes loading: false, import_batch_id: nil
    # commit.blobs.update_all loading: false
    blob_shas = commit.blobs_commits.pluck(:sha_raw)
    Blob.where(project_id: commit.project_id, sha_raw: blob_shas).update_all loading: false
  end
end
