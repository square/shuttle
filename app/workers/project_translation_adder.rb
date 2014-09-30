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
    key_ids = key_ids_with_commits(project)
    return if key_ids.blank?

    project.translation_adder_batch.jobs do
      key_ids.each do |key_id|
        KeyTranslationAdder.perform_once(key_id)
      end
    end
  end

  private

  # @return [Array<Key>] ids of all {Key keys} who belong to at least one {Commit} under this {Project}

  def key_ids_with_commits(project)
    key_ids = project.keys.pluck(:id)
    CommitsKey.where(key_id: key_ids).uniq('key_id').select('key_id').map(&:key_id)
  end

  include SidekiqLocking
end
