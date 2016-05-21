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

class CommitsCleaner
  include Sidekiq::Worker
  sidekiq_options queue: :high, retry: 5

  def perform
    log("Cleaning old commits for #{Date.today}")
    destroy_commits_on_no_branch
    destroy_old_commits_which_errored_during_import
    destroy_old_excess_commits_per_project
    destroy_commits_on_no_branch
  end

  include SidekiqLocking

  def destroy_commits_on_no_branch
    log("[destroy_commits_on_no_branch")
    Project.find_each do |project|
      project.repo(&:fetch)
      project.commits.not_ready.each do |commit|
        destroy_and_notify_stash(commit) unless commit.on_any_branch?
      end
    end
  end

  # Destroys any commit older than 2 days, which errored during an import.
  def destroy_old_commits_which_errored_during_import
    log("[destroy_old_commits_which_errored_during_import]")
    Commit.errored_during_import.where("created_at < ?", 2.days.ago).each do |commit|
      log("import errors for #{commit.revision}: #{commit.import_errors}")
      destroy_and_notify_stash(commit)
    end
  end

  # Destroys old commits from projects if there are too many of them.
  # For each project, only keep 100 most recent `ready` commits.
  def destroy_old_excess_commits_per_project
    log("[destroy_old_excess_commits_per_project]")
    Project.find_each do |project|
      project.commits.ready.order('created_at DESC').offset(100).each do |commit|
        destroy_and_notify_stash(commit)
      end
    end
  end

  private

  # Destroys a commit, notifies stash that the commit no longer exists in Shuttle
  def destroy_and_notify_stash(commit)
    log("Destroying commit #{commit.revision}")
    StashWebhookHelper.new.ping(commit, purged: true)
    commit.destroy
  end

  def log(message)
    Rails.logger.info "[maintenance:cleanup_commits] #{message}"
  end
end
