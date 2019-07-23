# Copyright 2016 Square Inc.
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

# This worker stops sidekiq worker gracefully after draining existing running jobs.
class SidekiqWorkerRestarter
  include Sidekiq::Worker
  sidekiq_options queue: :high, retry: false

  MIN_RUNNING_PROCESSES = 4
  MAX_RUNNING_DURATION = 3.hours

  def perform
    Rails.logger.info("Sidekiq Worker Restarter - started")
    processes = Sidekiq::ProcessSet.new.sort { |p1, p2| p1['started_at'] - p2['started_at'] }
    record_sidekiq_metrics(processes)
    restart_oldest_process(processes)
  end

  def restart_oldest_process(processes)
    # finds process in quiet state
    process = processes.select { |p| p['quiet'] == 'true' }.first
    if process.present?
      if process['busy'] == 0
        Rails.logger.info("Sidekiq Worker Restarter - signal quiet worker #{process['pid']} to stop")
        process.stop!
      else
        Rails.logger.info("Sidekiq Worker Restarter - quiet worker #{process['pid']} is busy (#{process['busy']} jobs)")
      end
      return
    end

    # Sidekiq::ProcessSet misses some workers sometimes for unknown reason.
    # checks if there are enough available running processes
    if processes.count <= MIN_RUNNING_PROCESSES
      Rails.logger.info("Sidekiq Worker Restarter - no enough running workers (#{processes.count} workers)")
      return
    end

    # finds process running longer enough to restart
    expiration_time = MAX_RUNNING_DURATION.ago
    process = processes.select { |p| p['started_at'] < expiration_time.to_i }.first
    if process.present?
      Rails.logger.info("Sidekiq Worker Restarter - signal worker #{process['pid']} to quiet")
      process.quiet!
    else
      Rails.logger.info("Sidekiq Worker Restarter - no expired worker found")
    end
  end

  def record_sidekiq_metrics(processes)
    host_processes = processes.group_by { |p| p['hostname'] }
    host_to_longevities = {}
    host_processes.each do |hostname, ps|
      min_started_at = ps.map { |p| p['started_at'] }.min
      host_to_longevities[hostname] = Time.now.to_i - min_started_at
    end
    CustomMetricHelper.record_sidekiq_longevity(host_to_longevities)

    busy_jobs = processes.map { |x| x['busy'] }.sum
    enqueued_jobs = Sidekiq::Stats.new.enqueued
    CustomMetricHelper.record_sidekiq_jobs(busy_jobs, enqueued_jobs)
  end

  include SidekiqLocking
end
