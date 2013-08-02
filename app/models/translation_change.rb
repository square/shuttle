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
# Properties
# ==========
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
    return unless translation.translated_changed? || translation.approved_changed? || translation.copy_changed?
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
