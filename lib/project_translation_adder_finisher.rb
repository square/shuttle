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

# Contains hooks run by Sidekiq upon completion of a ProjectTranslationAdder batch.

class ProjectTranslationAdderFinisher

  # Run by Sidekiq after a ProjectTranslationAdder batch finishes successfully.
  # Triggers a ProjectTranslationAdderOnSuccess job

  def on_success(_status, options)
    ProjectTranslationAdderOnSuccess.perform_once options['project_id']
  end
end