# Copyright 2015 Square Inc.
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

TOUCHDOWN_BRANCH_KEY = 'shuttle_settings:touchdown_running'

namespace :touchdown do
  desc "Updates touchdown branches"
  task update: :environment do
    start_time = Time.now
    Rails.logger.info "[touchdown:update] Attempting to run touchdown branch updater."

    # only run one instance of this cron
    if Shuttle::Redis.exists(TOUCHDOWN_BRANCH_KEY)
      Rails.logger.info "[touchdown:update] Unable to obtain lock."
      exit
    end

    Shuttle::Redis.setex TOUCHDOWN_BRANCH_KEY, 1.hour, '1'
    Rails.logger.info "[touchdown:update] Successfully obtained lock.  Queuing touchdown workers."

    Project.git.each do |project|
      BranchTouchdowner.perform_once(project.id)
    end

    Shuttle::Redis.del TOUCHDOWN_BRANCH_KEY
    Rails.logger.info "[touchdown:update] Releasing lock.  Successfully queued touchdown branch workers. Took #{(Time.now - start_time).round} seconds."
  end
end
