namespace :commit_fingerprint do
  desc "Updates commits with a fingerprint of it's commits_keys"
  task update: :environment do
    puts "[commit_fingerprint:update] Updating fingerprints on commits."

    Commit.includes(:commits_keys).all.each do |commit|
      # calculate the new fingerprint
      fingerprint = Digest::SHA1.hexdigest(commit.commits_keys.order(:key_id).pluck(:key_id).join(','))

      # save this commit with the fingerprint
      commit.fingerprint = fingerprint
      # assume this isn't a duplicate
      commit.duplicate = false
      commit.save!

      # update all commits except for the oldest with the same fingerprint as duplicates
      duplicates = Commit.where(fingerprint: fingerprint).order(created_at: :asc).limit(1000).offset(1)
      # this needs to be done in 2 steps because update_all doesn't take into account the offset
      Commit.where(id: duplicates.map(&:id)).update_all(duplicate: true)
    end

    puts "[commit_fingerprint:update] Fingerprinting finished."
  end
end
