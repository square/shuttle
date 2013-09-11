# Copyright 2013 Square Inc.
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

# Queues jobs to add or remove pending {Translation Translations} from
# {Key Keys} for this project for locales that have been added to or removed
# from a {Project}.

class ProjectTranslationAdder
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] project_id The ID of a Project.

  def perform(project_id)
    project = Project.find(project_id)
    worker_queue = "KeyTranslationAdder:#{SecureRandom.uuid}"

    project.keys.each do |key|
      Shuttle::Redis.sadd(worker_queue, KeyTranslationAdder.perform_once(key.id))
    end

    # Try for up to 1 hour
    720.times do
      break if Shuttle::Redis.scard(worker_queue) == 0
      sleep(5)
    end 

    project.commits.each do |commit|
      CommitStatsRecalculator.perform_once(commit.id)
    end 
  end

  include SidekiqLocking
end
