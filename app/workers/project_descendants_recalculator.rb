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

# Recalculates readiness of Keys, Commits and Articles in project
# since readiness hooks were disabled during the previous task (ex: `ProjectTranslationsAdderAndRemover`).
#
# This task could also be run in the batch finisher on success directly. However, this is a long running operation and
# it's safer to run as a separate job. For example, if an error is raised in this task, it will be re-queued and
# re-run. In the finisher, it would not be re-queued. Restarting sidekiq and deploying is also safer this way for
# the same reason.

# Also, this is generic enough that it can be run after multiple different events.
# Should be run after making changes to multiple Keys/Translations of a Project.

class ProjectDescendantsRecalculator
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] project_id The ID of a Project.

  def perform(project_id)
    project = Project.find(project_id)

    # the readiness hooks were all disabled, so now we need to go through and calculate readiness.
    Key.batch_recalculate_ready!(project)

    project.commits.find_each do |commit|
      CommitRecalculator.perform_once(commit.id)
    end

    project.articles.find_each do |article|
      ArticleRecalculator.perform_once(article.id)
    end
  end

  include SidekiqLocking
end
