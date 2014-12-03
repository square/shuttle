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

# Adds or removes pending {Translation Translations} for locales that have
# been added to or removed from a {Key}'s {Project}.

class KeyTranslationAdderAndRemover
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] id The ID of a Key.

  def perform(id)
    key = Key.find(id)
    key.add_pending_translations
    key.remove_excluded_pending_translations
  end

  include SidekiqLocking
end
