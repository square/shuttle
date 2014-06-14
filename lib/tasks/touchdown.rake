TOUCHDOWN_BRANCH_KEY = 'touchdown_running'

namespace :touchdown do
  desc "Updates touchdown branches"
  task :update do
    # only run one instance of this cron
    return if Shuttle::Redis.exists(TOUCHDOWN_BRANCH_KEY)
    Shuttle::Redis.set TOUCHDOWN_BRANCH_KEY, '1'

    Project.find_each &:update_touchdown_branch

    Shuttle::Redis.del TOUCHDOWN_BRANCH_KEY
  end
end
