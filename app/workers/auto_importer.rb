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

# Periodic Sidekiq worker that checks a remote branch for new commits, and
# imports them if present. This specific worker loads all applicable projects
# and spawns a {ProjectAutoImporter} for each one.

class AutoImporter
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Runs this worker.

  def perform
    Project.git.find_each do |project|
      next unless project.watched_branches.present?
      ProjectAutoImporter.perform_once project.id
    end
  end

  include SidekiqLocking

  # Loads a project, fetches its repo, and then spawns CommitImporters for the
  # most recent commit on each watched branch (unless that commit has already
  # been imported).

  class ProjectAutoImporter
    include Sidekiq::Worker
    sidekiq_options queue: :low

    # Runs this worker.
    #
    # @param [Fixnum] project_id The Project's ID.

    def perform(project_id)
      project = Project.find(project_id)
      return unless project.git? && project.watched_branches.present?

      project.repo &:fetch

      branches_to_delete = [] # any branches that don't actually exist anymore?
      project.watched_branches.each do |branch|
        begin
          project.commit! branch, other_fields: {description: "Automatically imported from the #{branch} branch"}
        rescue Git::CommitNotFoundError => err
          branches_to_delete << branch # branch doesn't actually exist; remove from watched branches and ignore
        end
      end
      project.watched_branches = project.watched_branches - branches_to_delete
      project.save!

    rescue Timeout::Error => err
      Squash::Ruby.notify err, project_id: project_id
      self.class.perform_in 2.minutes, project_id
    end

    include SidekiqLocking
  end
end
