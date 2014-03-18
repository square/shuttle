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

# Periodic Sidekiq worker that updates the touchdown branch for a given
# {Project}.

class TouchdownBranchUpdater
  include Sidekiq::Worker
  sidekiq_options queue: :low, failures: :exhausted

  # Runs this worker.
  #
  # @param [Fixnum] project_id The ID of a Project.

  def perform(project_id)
    Project.find_by_id(project_id).try!(:update_touchdown_branch)
  end

  include SidekiqLocking
end
