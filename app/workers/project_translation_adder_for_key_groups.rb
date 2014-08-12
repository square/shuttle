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

# This worker is for when a Project's locale settings change.
# When that happens, we need to check if there are any KeyGroups inheriting
# their locale settings from the Project. If there are, it means that
# we need to update these KeyGroups as necessary. The least error-prone way
# is a reimport of these KeyGroups. Since KeyGroups will generally not include too many strings,
# this should not be a big performance impact.

class ProjectTranslationAdderForKeyGroups
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # Finds KeyGroups which inherit locale settings from Project (meaning their targeted_rfc5646_locales is nil),
  # and re-imports them.
  #
  # @param [Fixnum] project_id The ID of a Project.

  def perform(project_id)
    Project.find(project_id).key_groups.each do |key_group|
      unless key_group.targeted_rfc5646_locales
        begin
          key_group.import!
        rescue KeyGroup::LastImportNotFinished
          # Doesn't do anything yet. But this could potentially send out an email informing the user of
          # what is happening and why import didn't succeed.
        end
      end
    end
  end

  include SidekiqLocking
end
