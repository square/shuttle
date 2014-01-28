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

namespace :maintenance do
  desc "Locate hung commits and clear their worker queue"
  task fix_hung_commits: :environment do
    Commit.where(loading: true).select(&:broken?).each(&:clear_workers!)
  end

  desc "Locates lockfiles that no longer refer to active processes and clears them"
  task clear_stale_lockfiles: :environment do
    workers      = Shuttle::Redis.smembers('workers').select { |w| w.start_with? Socket.gethostname }
    sidekiq_pids = workers.map { |w| w.split(':')[1].split('-').first.to_i }

    Dir.glob(Rails.root.join('tmp', 'repos', '*.lock')).each do |lockfile|
      lockfile_contents = File.read(lockfile) rescue next # race condition
      info_line         = lockfile_contents.split("\n").first
      _, pid, thread_id = info_line.split(', ').map { |part| part.split('=').last }

      # the process must exist ...
      next if Process.exist?(pid.to_i) && (
          # ... and either it's not a Sidekiq process ...
          !sidekiq_pids.include?(pid.to_i) ||
          # ... or if it is a Sidekiq process, a worker with that thread ID must exist
          workers.detect { |w| w.split(':')[1] == "#{pid}-#{thread_id}" }
      )

      # if we're still here, the worker has terminated and left the lockfile hanging around
      FileUtils.rm_f lockfile
    end
  end

  desc "Locates un-ready commits that probably should be ready and recalculates their stats"
  task recalculate_suspiciously_not_ready_commits: :environment do
    start_time = Time.now
    # if the commit isn't ready...
    Commit.where(loading: false, ready: false).order('id DESC').find_each do |c|
      # ... but it probably should be ready ...
      if c.translations_done == c.translations_total
        # don't spend more than half an hour doing this so we don't get cron jobs stacking up
        if Time.now - start_time <= 30.minutes
          # recalculate the commit inline
          CommitStatsRecalculator.new.perform(c.id)
        end
      end
    end
  end
end
