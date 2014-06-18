TOUCHDOWN_BRANCH_KEY = 'touchdown_running'

namespace :touchdown do
  desc "Updates touchdown branches"
  task update: :environment do
    start_time = Time.now 
    Rails.logger.info "[touchdown:update] Attempting to run touchdown branch updater."

    # only run one instance of this cron
    if Shuttle::Redis.exists(TOUCHDOWN_BRANCH_KEY)
      Rails.logger.info "[touchdown:update] Unable to obtain lock."
      return 
    end 
    Shuttle::Redis.set TOUCHDOWN_BRANCH_KEY, '1'
    Rails.logger.info "[touchdown:update] Successfully obtained lock.  Updating touchdown branch."

    Project.each do |p| 
      project_start_time = Time.now 
      Rails.logger.info "[touchdown:update] Starting update for project #{p.name}."
      p.update_touchdown_branch
      Rails.logger.info "[touchdown:update] Successfully updated touchdown branch for project #{p.name}.  Took #{(Time.now - project_start_time).round} seconds."  
    end 

    Shuttle::Redis.del TOUCHDOWN_BRANCH_KEY
    Rails.logger.info "[touchdown:update] Releasing lock.  Successfully updated touchdown branch. Took #{(Time.now - start_time).round} seconds."
  end
end
