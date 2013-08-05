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

# A change in a {Translation}. Currently tracks a {Translation}'s `copy` and
# `approved` fields. A TranslationChange exists for every time a {Translation}
# is edited.
#
# Associations
# ============
#
# |               |                                     |
# |:--------------|:------------------------------------|
# | `translation` | The {Translation} that was changed. |
# | `user`        | The {User} that made the change.    |
#
# Metadata
# ========
#
# |        |                           |
# |:-------|:--------------------------|
# | `diff` | The changes that occured. |

class TranslationChange < ActiveRecord::Base
  belongs_to :translation, inverse_of: :translation_changes
  belongs_to :user

  include HasMetadataColumn
  has_metadata_column(
    diff: {type: Hash, default: {}}
  )

  validates :translation, presence: true

  def self.create_from_translation!(translation)
    # Only track changes we care about
    tracked = [:translated, :approved, :copy]
    return unless tracked.any? { |t| translation.send(:"#{t}_changed?") }
    change = TranslationChange.new(translation: translation, user: translation.modifier)
    diff = translation.changes.slice("copy", "approved")

    # Necessary due to assign_attributes pushing back the cache; see TranslationsController#update
    diff["copy"] = [translation.copy_actually_was, translation.copy] if translation.copy_actually_was
    diff = diff.select { |k,v| v[0] != v[1] } # Filter for duplicates
    return if diff.empty?

    change.diff = diff
    change.save!
    change.freeze
  end
end
