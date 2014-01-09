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
  has_many :translation_changes, inverse_of: :translation, dependent: :delete_all

  include HasMetadataColumn
  has_metadata_column(
      source_copy:  {allow_blank: true},
      copy:         {allow_nil: true}
  )

  before_validation { |obj| obj.source_copy = '' if obj.source_copy.nil? }

  extend LocaleField
  locale_field :source_locale, from: :source_rfc5646_locale
  locale_field :locale

  include Tire::Model::Search
  include Tire::Model::Callbacks
  mapping do
    # use send(:key) instead of key because there is a variable that shadows the
    # key method.
    indexes :copy, analyzer: 'snowball', as: 'copy'
    indexes :source_copy, analyzer: 'snowball', as: 'source_copy'
    indexes :id, type: 'integer', index: :not_analyzed
    indexes :project_id, type: 'integer', as: 'send(:key).project_id'
    indexes :translator_id, type: 'integer'
    indexes :rfc5646_locale, type: 'string'
    indexes :created_at, type: 'date'
    indexes :translated, type: 'boolean'
    indexes :approved, type: 'integer', as: 'if approved==true then 1 elsif approved==false then 0 else nil end'
    indexes :commit_ids, as: 'send(:key).commits_keys.map(&:commit_id)'
  end

  validates :key,
            presence: true,
            if:       :key_id
  validates :source_rfc5646_locale,
            presence: true
  validates :rfc5646_locale,
            presence:   true,
            uniqueness: {scope: :key_id, on: :create}
  validate :cannot_approve_or_reject_untranslated
  validate :valid_interpolations, on: :update

  before_validation { |obj| obj.translated = obj.copy.to_bool; true }
  before_validation :approve_translation_made_by_reviewer, on: :update
  before_validation :count_words
  before_validation :populate_pseudo_translation

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

  # @private
  # @return [User] The person who changed this Translation
  attr_accessor :modifier

  # @private
  # The attributes we want TranslationChange to log
  def self.tracked_attributes() [:approved, :copy] end

  tracked_attributes.each { |a| attr_accessor :"#{a}_actually_was" }

  # TODO:
  def self.total_words 
    Translation.not_base.sum(:words_count)
  end 

  # TODO:
  def self.total_words_new
    Project.all.inject(0) do |sum, project|
      sum += project.translations
                    .not_base
                    .where(translated: false, rfc5646_locale: project.required_locales.map(&:rfc5646))
                    .sum(:words_count)
    end
  end 

  # TODO:
  def self.total_words_pending
    Project.all.inject(0) do |sum, project|
      sum += project.translations
                    .not_base
                    .where('approved IS NOT TRUE')
                    .where(translated: true, rfc5646_locale: project.required_locales.map(&:rfc5646))
                    .sum(:words_count)
    end
  end 

  # TODO:
  def self.total_words_per_project
    Translation.not_base.joins(key: :project)
      .select("sum(words_count), projects.name").group("projects.name")
      .order("sum DESC")
      .map { |t| [t.name, t.sum] }
  end 


  # Method used to cached the current state of the Translation
  # Required before making changes to a Translation that will be saved
  def freeze_tracked_attributes
    self.class.tracked_attributes.each do |a|
      send(:"#{a}_actually_was=", send(a))
    end
  end

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

  # @private
  def inspect(default_behavior=false)
    return super() if default_behavior
    state = case approved
              when true then 'approved'
              when false then 'rejected'
              else translated? ? 'translated' : 'untranslated'
            end
    "#<#{self.class.to_s} #{id}: Key #{key_id} in #{rfc5646_locale} (#{state})>"
  end

  private

  def valid_interpolations
    return unless copy.present? && copy_changed?
    return if base_translation? #TODO should we provide some kind of warning to the engineer?

    validating_copy = copy.dup

    # Remove fences from the copy as we validate them, so that they don't
    # interfere with futre validations
    key.fencers.each do |fencer|
      fencer_module = Fencer.const_get(fencer)
      unless fencer_module.valid?(validating_copy)
        errors.add(:copy, :invalid_interpolations, fencer: I18n.t("fencer.#{fencer}"))
        break
      end
      fences = fencer_module.fence(validating_copy).values.flatten.sort_by(&:first).reverse
      fences.each { |fence| validating_copy[fence] = '' }
    end
  end

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

  def populate_pseudo_translation
    return true unless locale.pseudo?
    self.copy ||= PseudoTranslator.new(locale).translate(source_copy)
    self.translated = true
    self.approved = true
    self.preserve_reviewed_status = true
  end

  # if the translation was updated post-approval, no associated commits will
  # have their readiness state changed (since the translation was and is still
  # approved), and therefore, manifests that should now be stale would not be,
  # were it not for this handy hook
  def expire_affected_cached_manifests
    # if we changed the copy but kept the approval status, we need to expire the
    # cache
    if copy != copy_was && approved? && !approved_changed?
      # clear out existing cache entries if present
      # can't use copy_changed? because we overwrite the copy with itself, which
      # does record a change (sigh)
      TranslationCachedManifestExpirer.perform_once self.id
    end
  end
end
