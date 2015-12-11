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
# | `issues`     | The {Issue Issues} under the translation.        |
#
# Properties
# ==========
#
# |                 |                                                       |
# |:----------------|:------------------------------------------------------|
# | `translated`    | If `true`, the copy has been translated.              |
# | `approved`      | If `true`, the copy has been approved for release.    |
# | `source_locale` | The locale the copy is translated from.               |
# | `locale`        | The locale the copy is translated to.                 |
# | `source_copy`   | The copy for the string in the project's base locale. |
# | `copy`          | The translated copy.                                  |

class Translation < ActiveRecord::Base
  has_one :article, through: :key
  belongs_to :key, inverse_of: :translations
  belongs_to :translator, class_name: 'User', foreign_key: 'translator_id', inverse_of: :authored_translations
  belongs_to :reviewer, class_name: 'User', foreign_key: 'reviewer_id', inverse_of: :reviewed_translations
  has_many :translation_changes, inverse_of: :translation, dependent: :delete_all
  has_many :issues, inverse_of: :translation, dependent: :destroy
  has_many :commits_keys, primary_key: :key_id, foreign_key: :key_id
  has_many :locale_associations, primary_key: :rfc5646_locale, foreign_key: :source_rfc5646_locale

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
    indexes :article_id, type: 'integer', as: 'send(:key).section.try(:article_id)'
    indexes :section_id, type: 'integer', as: 'send(:key).section_id'
    indexes :section_active, type: 'boolean', as: 'send(:key).section.try(:active)'
    indexes :index_in_section, type: 'integer', as: 'send(:key).index_in_section'
    indexes :translator_id, type: 'integer'
    indexes :rfc5646_locale, type: 'string', index: :not_analyzed
    indexes :created_at, type: 'date'
    indexes :updated_at, type: 'date'
    indexes :translated, type: 'boolean'
    indexes :approved, type: 'integer', as: 'if approved==true then 1 elsif approved==false then 0 else nil end'
  end

  validates :key,
            presence: true,
            if:       :key_id
  validates :source_rfc5646_locale,
            presence: true
  validates :rfc5646_locale,
            presence:   true,
            uniqueness: {scope: :key_id, on: :create}
  validates :notes, length: { maximum: 1024 }
  validate :cannot_approve_or_reject_untranslated
  validate :valid_interpolations, on: :update
  validate :fences_must_match

  before_validation { |obj| obj.translated = obj.copy.to_bool; true }
  before_validation :count_words
  before_validation :populate_pseudo_translation

  before_save { |obj| obj.translated = obj.copy.to_bool; true } # in case validation was skipped
  before_update :reset_reviewed, unless: :preserve_reviewed_status

  attr_readonly :source_rfc5646_locale, :rfc5646_locale, :key_id

  # @return [true, false] If `true`, the value of `reviewed` will not be reset
  #   even if the copy has changed.
  attr_accessor :preserve_reviewed_status

  # @private
  # @return [User] The person who changed this Translation
  attr_accessor :modifier

  # TODO: Fold this into DailyMetric?
  def self.total_words_per_project
    Translation.not_base.joins(key: :project)
      .select("sum(words_count), projects.name").group("projects.name")
      .order("sum DESC")
      .map { |t| [t.name, t.sum] }
  end

  scope :in_locale, ->(*langs) {
    if langs.size == 1
      where(rfc5646_locale: langs.first.rfc5646)
    else
      where(rfc5646_locale: langs.map(&:rfc5646))
    end
  }
  scope :approved, -> { where(translations: { approved: true }) }
  scope :not_approved, -> { where("translations.approved IS NOT TRUE") }
  scope :not_translated, -> { where(translations: { translated: false } ) }
  scope :base, -> { where('translations.source_rfc5646_locale = translations.rfc5646_locale') }
  scope :not_base, -> { where('translations.source_rfc5646_locale != translations.rfc5646_locale') }
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

  # Returns the commit which probably created this Translation's Key.
  # We cannot guarantee that this commit is actually the first ever commit that introduced this Key
  # to the codebase for several reasons:
  #   - `git blame` during Key creation wouldn't be very accurate because some projects such as
  #     iOS register has a script that creates the strings files by parsing their code
  #   - not all SHAs are submitted to Shuttle
  #   - SHAs submitted to Shuttle may not be in the correct order
  #   - we delete old commits, so the results returned with this method will be less accurate over time
  #
  # @return [Commit, nil] the first Commit in Shuttle which includes this Translation's Key

  def potential_commit
    @_potential_commit ||= key.commits.order(:id).first
  end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
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

  # @return [true, false] Whether this Translation belongs to an article or not.

  def belongs_to_article?
    !!key.section
  end

  private

  def valid_interpolations
    return unless copy.present? && copy_changed?
    return if base_translation? #TODO should we provide some kind of warning to the engineer?
    return if key.fencers.empty?

    validating_copy = copy.dup

    # Only validates for the first fencer
    fencer = key.fencers.first
    fencer_module = Fencer.const_get(fencer)
    unless fencer_module.valid?(validating_copy)
      errors.add(:copy, :invalid_interpolations, fencer: I18n.t("fencer.#{fencer}"))
    end
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

  def fences_must_match
    return if locale.pseudo? # don't validate if locale is pseudo
    return if copy.nil? # don't validate if we are just saving a not-translated translation. copy will be nil, and translation will be pending.
    errors.add(:copy, :unmatched_fences) unless fences.keys.sort == source_fences.keys.sort
    # Need to be careful when comparing. Should not use a comparison method which will compare hashcodes of strings
    # because of non-ascii characters such as the following:
    # `   "べ<span class='sales-trends'>"[1..27].hash == "<span class='sales-trends'>".hash  ` returns false
    # `   "べ<span class='sales-trends'>"[1..27] == "<span class='sales-trends'>"   `          returns true
  end

  # Batch updates `obj`s Translations in elastic search.
  # Expects `obj` to have a `keys` association.
  # This is currently only run in ArticleImporter::Finisher.
  #
  # @param [Commit, Project, Article] obj The object whose translations should be batch refreshed in ElasticSearch

  def self.batch_refresh_elastic_search(obj)
    obj.keys.includes(:translations, :section).find_in_batches do |keys|
      Translation.tire.index.import keys.map(&:translations).flatten
    end
  end
end
