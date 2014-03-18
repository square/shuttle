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

# After a {Project}'s required locales is changed, we need to recalculate the
# "readiness" of every {Commit} under that Project, which requires recalculating
# the readiness of every {Key}.

class ProjectReadinessRecalculator
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] project_id The ID of a Project.

  def perform(project_id)
    project = Project.find(project_id)

    project.keys.each do |key|
      key.skip_readiness_hooks = true
      key.recalculate_ready!
    end

    project.commits.find_each do |commit|
      commit.recalculate_ready!
    end
  end

  include SidekiqLocking
end
