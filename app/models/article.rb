# Copyright 2015 Square Inc.
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

# Represents a hash of {Section Sections}, and provides a thin layer of abstraction over them.
#
# Importing
# ---------
#
# An Article will be imported after creation, for the first time.
# If the source copy hash or locale settings change, it will be re-imported.
#
# `import!` method is the single point of entry for the import process.
# This will enqueue an ArticleImporter job which will handle the rest
# of the import in a Sidekiq Batch.
#
#
# Name uniqueness
# --------------
#
# The `name` field of Article is treated as a unique identifier within a Project.
#
#
# Locale Settings
# ---------------
# `base_locale` and `locale_requirements` fields store these settings. If nil,
# locale settings are inherited from Project's settings.
#
#
# Associations
# ============
#
# |                |                                                            |
# |:---------------|:-----------------------------------------------------------|
# | `project`      | The {Project} this Article belongs to                      |
# | `sections`     | The {Section Sections} that belong to this Article         |
# | `keys`         | The {Key Keys} that belong to this Article                 |
# | `translations` | The {Translation Translations} that belong to this Article |
#
# Fields
# ======
#
# |                             |                                                                                                                   |
# |:----------------------------|:------------------------------------------------------------------------------------------------------------------|
# | `name`                      | The unique identifier for this Section. This will be a user input in most cases.                                  |
# | `sections_hash`             | A hash mapping Section names to Section source copies.                                                            |
# | `description`               | A user submitted description. Can be used to provide context or instructions.                                     |
# | `email`                     | The email address that should be used for communications.                                                         |
# | `import_batch_id`           | The ID of the Sidekiq batch of import jobs.                                                                       |
# | `ready`                     | `true` when every required Translation under this Article has been approved.                                      |
# | `priority`                  | An priority defined as a number between 0 (highest) and 3 (lowest).                                               |
# | `due_date`                  | A date displayed to translators and reviewers informing them of when the Article must be fully localized.         |
# | `first_import_requested_at` | The timestamp of the first time an import of this Article was requested.                                          |
# | `last_import_requested_at`  | The timestamp of the last  time an import of this Article was requested.                                          |
# | `first_import_started_at`   | The timestamp of the first time an import of this Article was started.                                            |
# | `last_import_started_at`    | The timestamp of the last  time an import of this Article was started.                                            |
# | `first_import_finished_at`  | The timestamp of the first time an import of this Article was finished.                                           |
# | `last_import_finished_at`   | The timestamp of the last  time an import of this Article was finished.                                           |
# | `first_completed_at`        | The timestamp of the first time this Article was completed.                                                       |
# | `last_completed_at`         | The timestamp of the last  time this Article was completed.                                                       |
# | `base_locale`               | The locale the Article is initially localized in.                                                                 |
# | `locale_requirements`       | An hash mapping locales this Article can be localized to, to whether those locales are required.                  |

class Article < ActiveRecord::Base
  include ArticleOrCommitStats

  FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED = %w(sections_hash targeted_rfc5646_locales)

  extend SetNilIfBlank
  set_nil_if_blank :description, :due_date, :priority

  belongs_to :creator,    class_name: 'User'
  belongs_to :updater,    class_name: 'User'
  belongs_to :project,    inverse_of: :articles
  has_many :sections,     inverse_of: :article, dependent: :destroy
  has_many :keys,         through:    :sections
  has_many :translations, through:    :keys
  has_many :issues,       through:    :translations

  # Scopes
  scope :ready, -> { where(ready: true) }
  scope :not_ready, -> { where(ready: false) }
  # considered loading if import wasn't requested, wasn't finished, or re-requested since last finish time.
  scope :loading, -> { where("last_import_requested_at IS NULL OR last_import_finished_at IS NULL OR last_import_finished_at < last_import_requested_at") }

  attr_readonly :project_id

  serialize :sections_hash, Hash

  extend DigestField
  digest_field :name, scope: :for_name

  validates :project, presence: true, strict: true
  validates :name, presence: true, uniqueness: {scope: :project_id}
  validates :name, exclusion: { in: %w(new) } # this word is reserved because it collides with new_article_path.
  validates :sections_hash, presence: true
  validate  :valid_sections_hash
  validates :description, length: {maximum: 2000}, allow_nil: true
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_nil: true
  validates :ready,   inclusion: { in: [true, false] }, strict: true
  validates :priority, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3}, allow_nil: true
  validates :due_date, timeliness: {type: :date}, allow_nil: true
  validates :first_import_requested_at,
            :first_import_started_at,
            :first_import_finished_at,
            :first_completed_at,
            :last_import_requested_at,
            :last_import_started_at,
            :last_import_finished_at,
            :last_completed_at,
            timeliness: {type: :date}, allow_nil: true, strict: true

  def valid_sections_hash
    unless sections_hash.is_a?(Hash) &&
        sections_hash.keys.all? { |k| k.is_a?(String) && k.present? && k.length < 255 } &&
        sections_hash.values.all? { |k| k.is_a?(String) && k.present? }
      errors.add(:sections_hash, "wrong format")
    end
  end
  private :valid_sections_hash

  # Add import_batch and import_batch_status methods
  extend SidekiqBatchManager
  sidekiq_batch :import_batch do |batch|
    batch.description = "Import Article #{id} (#{project.name} - #{name})"
    batch.on :success, ArticleImporter::Finisher, article_id: id
  end

  # @param [String] n the name to find Article with
  # @return [Article, nil] the {Article} corresponding to the given name `n`, if any.

  def self.find_by_name(n)
    for_name(n).last if n
  end

  # ======== START LOCALE RELATED CODE =================================================================================
  include CommonLocaleLogic

  before_validation(on: :create) do |article|
    article.base_rfc5646_locale      = article.project.base_rfc5646_locale      if article.base_rfc5646_locale.blank?
    article.targeted_rfc5646_locales = article.project.targeted_rfc5646_locales if article.targeted_rfc5646_locales.blank?
  end
  # ======== END LOCALE RELATED CODE ===================================================================================


  # ======== START KEY & READINESS RELATED CODE ========================================================================

  # @return [Array<Section>] the active {Section Sections} in this Article.
  def active_sections
    sections.active
  end

  # @return [Array<Section>] the inactive {Section Sections} in this Article.
  def inactive_sections
    sections.inactive
  end

  # This leaves out the Keys which were once an active part of this Article, but are not active anymore.
  # `index_in_section` is used as a flag of activeness.
  #
  # @return [Array<Key>] the {Key Keys} that are actively related to this Article.

  def active_keys
    keys.merge(Section.active).merge(Key.active_in_section)
  end

  # @return [Array<Translation>] the {Translation Translations} that are actively related to this Article.
  def active_translations
    translations.merge(Section.active).merge(Key.active_in_section)
  end

  # @return [Array<Issue>] the {Issue Issues} that are actively related to this Article.
  def active_issues
    issues.merge(Section.active).merge(Key.active_in_section)
  end

  # Calculates the value of the `ready` field and saves the record.
  def recalculate_ready!
    keys_are_ready = !active_keys.merge(Key.not_ready).exists?
    ready_new = keys_are_ready && !loading?
    if !ready? && ready_new # if it just became ready
      self.last_completed_at = Time.current
      self.first_completed_at ||= self.last_completed_at
    end
    self.ready = ready_new
    self.save!
  end

  # Resets ready fields for this Article and its Keys.
  # It's necessary to call this after an import is scheduled, and after it's started.
  def full_reset_ready!
    update!(ready: false) if ready?
    keys.update_all(ready: false)
  end

  # For any key and any locale in targeted locales (required or not), the key cannot be skipped.
  # For any key and any locale not in targeted locales, the key can be skipped.
  #
  # @param [String] key that will be checked for skipping
  # @param [Locale] locale
  # @return [Boolean] true if the given `key` should be skipped for the given `locale`
  #       in this Article's context. false, otherwise.

  def skip_key?(key, locale)
    !targeted_locales.include?(locale)
  end

  # ======== END KEY & READINESS RELATED CODE ========================================================================


  # ======== START IMPORT RELATED CODE =================================================================================
  # This is the point of entry for the import process of an Article.
  # If anything changes related to this Article which may require a re-import,
  # such as `source_copy` changes or locale settings changes, this method is called.
  #
  # Schedules an ArticleImporter to do the actual import.
  #
  # It resets the ready fields of this Article and associated Keys to false
  # because some important change must have happened to kick off importing, and
  # we cannot guarantee that the Article or its Keys are ready any more.
  #
  # Updates import_requested_at timestamps.

  def import!(force_import_sections=false)
    raise Article::LastImportNotFinished if !!last_import_requested_at && loading?
    update_import_requested_at!
    full_reset_ready! # reset ready immediately without waiting for the ArticleImporter job to be processed
    import_batch.jobs { ArticleImporter.perform_once(id, force_import_sections) }
  end

  # Updates first and last import_requested_at fields.
  # Called only in an Article's `import!` method
  # @private

  def update_import_requested_at!
    new_attrs = {last_import_requested_at: Time.current}
    new_attrs[:first_import_requested_at] = new_attrs[:last_import_requested_at] unless first_import_requested_at
    self.update!(new_attrs)
  end
  private :update_import_requested_at!

  # Called only in the ArticleImporter at the start of an import job.
  #
  # Clears the `import_batch_id` so that we can force re-import a hanging Article import.
  # Right now, the Articles controller doesn't allow a re-import if the import is not finished,
  # but in the future, there can be an advanced action for admins to bypass that.
  #
  # Ready is set to false.
  #
  # First and last import_started_at timestamps are also updated as necessary.

  def update_import_starting_fields!
    new_attrs = { ready: false, last_import_started_at: Time.current }
    new_attrs[:first_import_started_at] = new_attrs[:last_import_started_at] unless first_import_started_at
    update!(new_attrs)
  end

  # Called only in the ArticlerImporter::Finisher's `on_success` method,
  # at the end of an import job.
  #
  # Clears the `import_batch_id` because we are done with that batch id and should not re-use it.
  #
  # First and last import_finished_at timestamps are also updated as necessary.

  def update_import_finishing_fields!
    new_attrs = { import_batch_id: nil, last_import_finished_at: Time.current }
    new_attrs[:first_import_finished_at] = new_attrs[:last_import_finished_at] unless first_import_finished_at
    update!(new_attrs)
  end

  # Loading is finished if the import has been requested & finished successfully, and have not been re-requested since.
  # If the import is scheduled but didn't start yet, it's considered 'loading'.
  # If the import is scheduled and started, it's also considered 'loading'.
  #
  # @return [true, false] true if the last import has been finished,
  #                       false otherwise.
  def loading?
    !last_import_requested_at || !last_import_finished_at || (last_import_requested_at > last_import_finished_at)
  end
  alias_method :loading, :loading?

  # ======== END IMPORT RELATED CODE ===================================================================================

  # ======== START ERRORS RELATED CODE =================================================================================
  # Raised when a re-import is called on an Article before the previous import didn't finish yet.
  class LastImportNotFinished < StandardError
  end
  # ======== END ERRORS RELATED CODE ===================================================================================

  # `name` is picked over `id` becase we want to allow consumers of Articles API to set a unique identifier
  # on their end. Both have disadvantages. One disadvantage of `id` is that if consumers call the `create`
  # endpoint twice with same params, it would create 2 duplicate Articles.

  def to_param
    name
  end
end
