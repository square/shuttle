TOUCHDOWN_BRANCH_KEY = 'touchdown_running'

namespace :touchdown do
  desc "Updates touchdown branches"
  task update: :environment do
    # only run one instance of this cron
    if Shuttle::Redis.exists(TOUCHDOWN_BRANCH_KEY)
      exit
    end

    Shuttle::Redis.set TOUCHDOWN_BRANCH_KEY, '1'
    Shuttle::Redis.expire TOUCHDOWN_BRANCH_KEY, 5.minutes

    Project.all.each do |p|
      p.update_touchdown_branch
    end

    Shuttle::Redis.del TOUCHDOWN_BRANCH_KEY
  end
end
