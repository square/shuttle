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

# Creates a set of {Key Key} associated with a {KeyGroup}, as part of an import job.
# Also creates {Translation Translations} in base & targeted locales related to the {Key}.

class KeyCreatorForKeyGroups
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker. Creates a Key and related Translations in base & targeted locales.
  # Since no `key` field is provided here, a `key` field will be formed using the `source_copy`.
  #
  # @param [Fixnum] key_group_id The ID of a {KeyGroup} this Key is parsed from.
  # @param [String] source_copy The source copy of the Key that will be created.
  # @param [Fixnum] index The index of Key that will be created here with respect
  #     to other Keys that will be created for this KeyGroup.

  def perform(key_group_id, source_copy, index)
    key_group = KeyGroup.find_by_id(key_group_id)

    # Create key
    # `index` is included in the `key` field to make sure that we will create different keys for duplicate paragraphs
    # in a KeyGroup, and also to make sure we can search by this field after de-activating this Key in a KeyGroup.
    # Read the Key model documentation for more info.

    key_name = KeyCreatorForKeyGroups.generate_key_name(source_copy, index)
    key = key_group.keys.for_key(key_name).create_or_update!(
        project:              key_group.project,
        key:                  key_name,
        index_in_key_group:   index,
        source_copy:          source_copy,
        skip_readiness_hooks: true,
        ready: false
    )

    # add missing translations for base and target locales
    key.add_pending_translations

    # remove unnecessary translations
    key.remove_excluded_pending_translations
  end

  def self.generate_key_name(source_copy, index)
    "#{index}:#{Key.new(source_copy: source_copy).tap(&:valid?).source_copy_sha}"
  end

  include SidekiqLocking
end
