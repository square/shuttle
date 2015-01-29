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

# Optimizes git repos by reducing disk space, increasing performance.
# Also prunes old remote-tracking branches, so that we don't experience namespace
# collisions between new and old branches.
# For more reference: http://git-scm.com/docs/git-gc, http://git-scm.com/docs/git-prune

class ReposCleaner
  def run
    git_projects_with_unique_repos.find_each do |project|
      Rails.logger.info "[maintenance:cleanup_repos] Cleaning up #{project.name} (#{project.id})"

      project.repo { |repo| gc_and_remote_prune(repo) }
    end
  end

  def git_projects_with_unique_repos
    ids = Project.git.group(:repository_url).select("min(id) as id").map(&:id)
    Project.where(id: ids)
  end

  def gc_and_remote_prune(repo)
    # This is a little hacky, but necessary. It runs "git gc --prune --auto".
    # The built in `repo.gc` method adds the '--aggressive' option which is
    # too slow, and this avoids that.
    repo.lib.send :command, :gc, ['--prune', '--auto']

    # This is also a little hacky, but necessary. It basically runs "git remote prune origin",
    # which prunes old remote-tracking branches that have been removed from the git repo.
    # We use the `command` method of Git::Lib instead of running the naked
    # command with `system` call because `command` method provides more abstractions
    # (such as `chdir`) which are needed to ensure this runs safely.
    repo.lib.send :command, :remote, [:prune, :origin]
  end
end

namespace :maintenance do
  desc "Cleans up git repos by garbage collection and pruning"
  task cleanup_repos: :environment do
    ReposCleaner.new.run
  end
end
