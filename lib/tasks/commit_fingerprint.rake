namespace :commit_fingerprint do
  desc "Updates commits with a fingerprint of it's commits_keys"
  task update: :environment do
    puts "[commit_fingerprint:update] Updating fingerprints on commits."

    Commit.includes(:commits_keys).order(created_at: :asc).all.each do |commit|
      # calculate the new fingerprint
      fingerprint = Digest::SHA1.hexdigest(commit.commits_keys.order(:key_id).pluck(:key_id).join(','))
      # update all the other commits with the same fingerprint as duplicates
      Commit.where(fingerprint: fingerprint).update_all(duplicate: true)
      # save this commit with the fingerprint
      commit.fingerprint = fingerprint
      commit.save!
    end

    puts "[commit_fingerprint:update] Fingerprinting finished."
  end
end
