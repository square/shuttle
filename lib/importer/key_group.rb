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

require 'set'

module Importer

  class KeyGroup
    BLOCK_LEVEL_TAGS = %w(p div li address article aside blockquote dl dd footer header section h1 h2 h3 h4 h5 h6)

    def initialize(key_group)
      @key_group = key_group
    end

    # Imports this KeyGroup.
    #
    # Sets `loading` to true, Resets `ready` to false for KeyGroup and its Keys.
    # Splits into paragraphs, rebases, and runs KeyCreatorForKeyGroups for each paragraph.

    def import_strings
      @key_group.update_import_starting_fields!
      @key_group.reset_ready! # in case readiness changed from the time import method was called to now

      paragraphs = split_into_paragraphs(@key_group.source_copy)

      if @key_group.keys.exists?
        rebase_existing_keys(paragraphs) # so that we can re-use the unchanged portions of the source copy
        deactivate_all_keys
      end

      @key_group.import_batch.jobs do
        paragraphs.each.with_index do |paragraph, index|
          KeyCreatorForKeyGroups.perform_once(@key_group.id, paragraph, index)
        end
      end

      # Commented this out because reset_approved_if_neighbor_changed! will reset approved for unused Translations
      # @key_group.translations.not_base.joins(:key).where(key: {index_in_key_group: nil}).update_all(approved: nil) # if there are any unused Translations at the end of a (re)import, unapprove them
    end

    private

    # The reason we rebase is that we want to re-use previous translations in case
    # someone adds and/or removes paragraphs to/from `source_copy` of the KeyGroup.
    # Since KeyCreatorForKeyGroups searches by the `index:source_copy_sha`, we want to
    # update the indexes of Keys before KeyCreatorForKeyGroups is run so that
    # it will match the old Key.
    #
    # Example: [a] -> [b a]
    # In this scenario, initially we had something like: [Key(index_in_key_group => 0, key => "0:a")].
    # It transformed to [Key(index => 0, key => "0:b"), Key(index_in_key_group => 1, key => "1:a")].
    # In this rebasing step, we update the initial key to be Key(index_in_key_group => nil, key => "1:a").
    # This way, in the KeyCreatorForKeyGroups step, "1:a" will be matched, and the key will be reused,
    # and its `index_in_key_group` will be set to 1.
    #
    # In case there are only changes in the `source_copy`, we also want to
    # prompt the translators that the context may have changed. But, we also don't want
    # the translators to look at every single Translation in the KeyGroup, because most
    # of that effort would be redundant. For that reason, we only reset the approved
    # states for the neighbors of changed paragraphs.
    #
    # Example: [a b] -> [a]
    # In this scenario, the approved state of Key(a) will be reset.

    def rebase_existing_keys(new_paragraphs) # Ex: ["Hello a", "Hello c", "Hello e"]
      existing_keys = @key_group.sorted_active_keys_with_translations # Ex: [<Key 1: 0:x:a>, <Key 2: 1:x:b>, <Key 3: 2:x:c>, <Key 4: 10:x:d>]
      existing_paragraphs = existing_keys.map(&:source_copy) # Ex: ["Hello a", "Hello b", "Hello c", "Hello d"]
      sdiff = Diff::LCS.sdiff(existing_paragraphs, new_paragraphs) # Ex: [["=", [0, "Hello a"], [0, "Hello a"]], ["-", [1, "Hello b"], [1, nil]], ["=", [2, "Hello c"], [1, "Hello c"]], ["!", [3, "Hello d"], [2, "Hello e"]]]

      reset_approved_if_neighbor_changed!(existing_keys, sdiff)
      update_indexes_of_unchanged_keys!(existing_keys, sdiff)
    end

    # Finds the not-unchanged keys (yeap, that's right. sounds like a double negative, but it's not), and marks their neighbors as pending.
    #
    # @param [Array<Key>] existing_keys the {Key Keys} in the {KeyGroup} before rebasing.
    #        ex:
    # @param [Array<Diff::LCS::ContextChange>] sdiff the difference between the old source_copy paragraphs and new source_copy paragraphs
    #        ex: [["+", [0, nil], [0, "b"]], ["=", [0, "a"], [1, "a"]]]

    def reset_approved_if_neighbor_changed!(existing_keys, sdiff)
      # Find keys whose neighbors have changed
      keys_to_be_marked_pending = Set.new
      sdiff.each do |diff|
        if diff.adding?
          keys_to_be_marked_pending.add(existing_keys[diff.old_position - 1]) if diff.old_position > 0 # this adds the previous neighbor
          keys_to_be_marked_pending.add(existing_keys[diff.old_position]) if diff.old_position < existing_keys.length # this adds the next neighbor
        end

        if diff.deleting? || diff.changed?
          keys_to_be_marked_pending.add(existing_keys[diff.old_position-1]) if diff.old_position > 0 # this adds the previous neighbor
          keys_to_be_marked_pending.add(existing_keys[diff.old_position]) # this adds self
          keys_to_be_marked_pending.add(existing_keys[diff.old_position+1]) if diff.old_position < existing_keys.length - 1 # this adds the next neighbor
        end
      end

      # Reset translations' approved status for keys whose neighbors have changed
      keys_to_be_marked_pending.each do |key|
        key.translations.not_base.each do |translation|
          translation.update!(approved: nil) if translation.approved?
        end
        key.recalculate_ready!
      end
    end

    # Find the {Key Keys} whose source_copy were not changed but whose index was changed.
    # Temporarily update their `key` fields to something you don't expect to see in the database.
    # Then set the real, new `key` fields.
    # This all happens in a transaction so that we don't get caught in a funny state.
    #
    # This doesn't update the `index_in_key_group` field. That should be set in the KeyCreaterForKeyGroups worker.
    #
    # @param [Array<Key>] existing_keys the {Key Keys} in the {KeyGroup} before rebasing.
    #        ex:
    # @param [Array<Diff::LCS::ContextChange>] sdiff the difference between the old source_copy paragraphs and new source_copy paragraphs
    #        ex: [["+", [0, nil], [0, "b"]], ["=", [0, "a"], [1, "a"]]]

    def update_indexes_of_unchanged_keys!(existing_keys, sdiff)
      existing_key_names = existing_keys.map(&:key) # Ex: ['0:a', '1:b', '2:c', '10:d']

      # Find which keys need to be rebased
      index_changes = sdiff.select { |diff| diff.unchanged? && (diff.old_position != diff.new_position) } # [["=", [0, "a"], [1, "a"]]]

      Key.transaction do
        # First, change the key names to different key names that would not normally be found in the database.
        # This key name will be temporary and will be set to something normal in the next step.
        # This will handle [a, a] -> [c, a, a]
        index_changes.each_with_index do |change, i|
          key = existing_keys[change.old_position] # Ex: <Key 1: 0:shaOfA>
          tmp_key_name = "_old_:#{key.key}" # Ex: "_old_:0:shaOfA"
          @key_group.keys.for_key(tmp_key_name).each{ |key| key.destroy! } # remove old keys that could be a conflict. There shouldn't be any such keys normally.
          key.update!(key: tmp_key_name, skip_readiness_hooks: true)
        end

        # Set the updated key names with updated indexes
        index_changes.each_with_index do |change, i|
          key = existing_keys[change.old_position] # Ex: <Key 1: _old_:0:shaOfA>
          new_key_name = KeyCreatorForKeyGroups.generate_key_name(key.source_copy, change.new_position)   # Ex: "1:shaOfA"
          @key_group.keys.for_key(new_key_name).each{ |key| key.destroy! } # remove old keys that could be a conflict. There shouldn't be any such keys normally.
          key.update!(key: new_key_name, skip_readiness_hooks: true)
        end
      end
    end

    # Splits a given text into smallest meaningful pieces that can each be translated as a unit.
    # This is done by splitting by block level tags.
    #
    # @param [String] text to be split into paragraphs
    # @return [Array<String>] array of paragraphs which can be translated as a unit

    def split_into_paragraphs(text)
      ### text.split(/(?=<.+?<\/p>)/m).map {|t| t.split(/(?<=<\/p>)/m)}.flatten
      arr = text.split( /#{BLOCK_LEVEL_TAGS.map{ |tag| "(?=<" + tag + ".+?<\/" + tag + ">)"}.join("|") }/m )
      arr = arr.map {|t| t.split(/#{BLOCK_LEVEL_TAGS.map{ |tag| "(?<=<\/" + tag + ">)" }.join("|") }/m)}
      arr.flatten.select(&:present?)
    end

    # Cleans associations between key_groups and keys so that we can start fresh.
    # A Key is considered to be inactive for a KeyGroup if index_in_key_group is nil.
    def deactivate_all_keys
      @key_group.keys.update_all(index_in_key_group: nil)
    end
  end
end
