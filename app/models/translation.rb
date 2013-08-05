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

require 'digest/sha2'

# A localization of a string to a certain locale. The base string is represented
# by a {Key}, unique to a Project. A Translation exists for every desired locale
# that the string should be translated to, as well as a base Translation whose
# target locale is the Project's base locale. This base Translation is
# automatically marked as approved; all other Translations must be approved by a
# reviewer {User} before they are considered suitable for re-merging back into
# the Project's code.
#
# Associations
# ============
#
# |              |                                                  |
# |:-------------|:-------------------------------------------------|
# | `key`        | The {Key} whose string this is a translation of. |
# | `translator` | The {User} who performed the translation.        |
# | `reviewer`   | The {User} who reviewed the translation.         |
#
# Properties
# ==========
#
# |                 |                                                    |
# |:----------------|:---------------------------------------------------|
# | `translated`    | If `true`, the copy has been translated.           |
# | `approved`      | If `true`, the copy has been approved for release. |
# | `source_locale` | The locale the copy is translated from.            |
# | `locale`        | The locale the copy is translated to.              |
#
# Metadata
# ========
#
# |               |                                                       |
# |:--------------|:------------------------------------------------------|
# | `source_copy` | The copy for the string in the project's base locale. |
# | `copy`        | The translated copy.                                  |

class Translation < ActiveRecord::Base
  belongs_to :key, inverse_of: :translations
  belongs_to :translator, class_name: 'User', foreign_key: 'translator_id', inverse_of: :authored_translations
  belongs_to :reviewer, class_name: 'User', foreign_key: 'reviewer_id', inverse_of: :reviewed_translations

  include HasMetadataColumn
  has_metadata_column(
      source_copy:  {allow_blank: true},
      copy:         {allow_nil: true}
  )

  before_validation { |obj| obj.source_copy = '' if obj.source_copy.nil? }

  extend LocaleField
  locale_field :source_locale, from: :source_rfc5646_locale
  locale_field :locale

  extend SearchableField
  searchable_field :copy, language_from: :locale
  searchable_field :source_copy, language_from: :source_locale

  validates :key,
            presence: true,
            if:       :key_id
  validates :source_rfc5646_locale,
            presence: true
  validates :rfc5646_locale,
            presence:   true,
            uniqueness: {scope: :key_id, on: :create}
  validate :cannot_approve_or_reject_untranslated

  before_validation { |obj| obj.translated = obj.copy.to_bool; true }
  before_validation :approve_translation_made_by_reviewer, on: :update
  before_validation :count_words

  before_save { |obj| obj.translated = obj.copy.to_bool; true } # in case validation was skipped
  before_update :reset_reviewed, unless: :preserve_reviewed_status

  after_save :recalculate_readiness, if: :apply_readiness_hooks?
  after_save :recalculate_commit_stats, if: :apply_readiness_hooks?
  after_save :expire_affected_cached_manifests

  after_commit :update_translation_memory, if: :apply_readiness_hooks?

  after_destroy :recalculate_readiness

  attr_readonly :source_rfc5646_locale, :rfc5646_locale, :key_id

  # @return [true, false] If `true`, the after-save hooks that recalculate
  #   Commit `ready?` values will not be run. You should use this when
  #   processing a large batch of Translations.
  attr_accessor :skip_readiness_hooks

  def apply_readiness_hooks?() !skip_readiness_hooks end
  private :apply_readiness_hooks?

  # @return [true, false] If `true`, the value of `reviewed` will not be reset
  #   even if the copy has changed.
  attr_accessor :preserve_reviewed_status

  scope :in_locale, ->(*langs) {
    if langs.size == 1
      where(rfc5646_locale: langs.first.rfc5646)
    else
      where(rfc5646_locale: langs.map(&:rfc5646))
    end
  }
  scope :base, -> { where('source_rfc5646_locale = rfc5646_locale') }
  scope :not_base, -> { where('source_rfc5646_locale != rfc5646_locale') }
  scope :in_commit, ->(commit) {
    commit_id = commit.kind_of?(Commit) ? commit.id : commit
    joins("INNER JOIN commits_keys ON translations.key_id = commits_keys.key_id").
        where(commits_keys: {commit_id: commit_id})
  }

  # @return [Hash<String, Array<Range>>] The fences generated by the fencer for
  #   this Translation's source text, or an empty hash if the copy has no
  #   fences.
  def source_fences() source_copy ? Fencer.multifence(key.fencers, source_copy) : {} end

  # @return [Hash<String, Array<Range>>] The fences generated by the fencer for
  #   this Translation's text, or an empty hash if the copy has no fences.
  def fences() copy ? Fencer.multifence(key.fencers, copy) : {} end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
    options[:except] << :metadata
    options[:except] << :translator_id << :reviewer_id << :key_id
    options[:except] << :searchable_copy << :searchable_source_copy
    options[:except] << :source_rfc5646_locale << :rfc5646_locale

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :source_locale << :locale
    options[:methods] << :source_fences

    super options
  end

  # @private
  def to_param() locale.rfc5646 end

  # @return [true, false] Whether this Translation represents a string in the
  #   Project's base locale.

  def base_translation?
    source_locale == locale
  end

  private

  def recalculate_readiness
    key.recalculate_ready! if destroyed? || translated_changed? || approved_changed?
  end

  def reset_reviewed
    if (copy != copy_was || source_copy != source_copy_was) && !base_translation? && !approved_changed?
      self.reviewer_id = nil
      self.approved    = nil
    end
    return true
  end

  def cannot_approve_or_reject_untranslated
    errors.add(:approved, :not_translated) if approved != nil && !translated?
  end

  def approve_translation_made_by_reviewer
    if translator_id_changed? && translator && translator.reviewer? && copy_changed? && translated?
      self.approved = true
      self.reviewer = translator
    end
    return true
  end

  def recalculate_commit_stats
    return unless translated_changed? || approved_changed?
    KeyStatsRecalculator.perform_once key_id
  end

  def update_translation_memory
    TranslationUnit.store self
  end

  def count_words
    self.words_count = source_copy.split(/\s+/).size
  end

  # if the translation was updated post-approval, no associated commits will
  # have their readiness state changed (since the translation was and is still
  # approved), and therefore, manifests that should now be stale would not be,
  # were it not for this handy hook
  def expire_affected_cached_manifests
    return unless copy_changed? && approved? && !approved_changed?
    # clear out existing cache entries if present
    TranslationCachedManifestExpirer.perform_once self.id
  end
end
