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

# A worker which will start an import for a {KeyGroup}.
# This worker is only scheduled in `import!` method of {KeyGroup} after it's become
# known that a re-import is needed.

class KeyGroupImporter
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker by calling `#import_strings` on {Importer::KeyGroup}.
  #
  # @param [Fixnum] key_group_id The ID of a KeyGroup.

  def perform(key_group_id)
    key_group = KeyGroup.find(key_group_id)
    Importer::KeyGroup.new(key_group).import_strings
  end

  include SidekiqLocking
end
