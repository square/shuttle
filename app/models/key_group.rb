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

# Represents a group of {Key Keys}. This can be an article or an email or
# any kind of content given. Keys are not shared across KeyGroups.
# Keys will be ordered in a KeyGroup. `index_in_key_group` field in Key model
# will store this information.
#
# Importing
# ---------
#
# A KeyGroup will be imported after creation, for the first time.
# If the source copy or locale settings change, it will be re-imported.
# If the project's locale settings change, it may also be re-imported,
# if this KeyGroup is inheriting locale settings from the project.
#
# `import!` method is the single point of entry for the import process.
# This will enqueue a KeyGroupImporter job which will handle the rest
# of the import in a Sidekiq Batch.
#
#
# Key uniqueness
# --------------
#
#
# The `key` field of KeyGroup is treated as a unique identifier within a Project.
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
# |                |                                                              |
# |:---------------|:-------------------------------------------------------------|
# | `project`      | The {Project} this KeyGroup belongs to.                      |
# | `keys`         | The {Key Keys} that belong to this KeyGroup.                 |
# | `translations` | The {Translation Translations} that belong to this KeyGroup. |
#
# Fields
# ======
#
# |                             |                                                                                                                    |
# |:----------------------------|:-------------------------------------------------------------------------------------------------------------------|
# | `key`                       | The unique identifier for this KeyGroup. This will be a user input in most cases.                                  |
# | `source_copy`               | The original source copy of this KeyGroup.                                                                         |
# | `description`               | A user submitted description of this KeyGroup. Can be used to provide context, or instructions about the KeyGroup. |
# | `email`                     | The email address that should be used for communications about this KeyGroup.                                      |
# | `import_batch_id`           | The ID of the Sidekiq batch of import jobs.                                                                        |
# | `loading`                   | If `true`, there is at least one Sidekiq job processing this KeyGroup.                                             |
# | `ready`                     | `true` when every required Translation under this KeyGroup has been approved.                                      |
# | `first_import_requested_at` | The timestamp of the first time an import of this KeyGroup was requested.                                          |
# | `last_import_requested_at`  | The timestamp of the last  time an import of this KeyGroup was requested.                                          |
# | `first_import_started_at`   | The timestamp of the first time an import of this KeyGroup was started.                                            |
# | `last_import_started_at`    | The timestamp of the last  time an import of this KeyGroup was started.                                            |
# | `first_import_finished_at`  | The timestamp of the first time an import of this KeyGroup was finished.                                           |
# | `last_import_finished_at`   | The timestamp of the last  time an import of this KeyGroup was finished.                                           |
# | `first_completed_at`        | The timestamp of the first time this KeyGroup was completed.                                                       |
# | `last_completed_at`         | The timestamp of the last  time this KeyGroup was completed.                                                       |
# | `base_locale`               | The locale the KeyGroup is initially localized in.                                                                 |
# | `locale_requirements`       | An hash mapping locales this KeyGroup can be localized to, to whether those locales are required.                  |

class KeyGroup < ActiveRecord::Base
  extend SetNilIfBlank

  FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED = %w(source_copy targeted_rfc5646_locales)

  belongs_to :project, inverse_of: :key_groups
  has_many :keys, inverse_of: :key_group
  has_many :translations, through: :keys

  extend DigestField
  digest_field :key, scope: :for_key
  digest_field :source_copy, scope: :source_copy_matches

  attr_readonly :project_id, :key

  validates :project, presence: true
  validates :key, presence: true
  validates :key_sha_raw, presence: true, uniqueness: {scope: :project_id}
  validates :source_copy, presence: true
  validates :source_copy_sha_raw, presence: true
  validates :description, length: {maximum: 2000}
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_nil: true
  validates :ready,   inclusion: { in: [true, false] }, strict: true
  validates :loading, inclusion: { in: [true, false] }, strict: true
  validates :first_import_requested_at,
            :first_import_started_at,
            :first_import_finished_at,
            :first_completed_at,
            :last_import_requested_at,
            :last_import_started_at,
            :last_import_finished_at,
            :last_completed_at,
                timeliness: {type: :date}, allow_nil: true, strict: true

  # Add import_batch and import_batch_status methods
  extend SidekiqBatchManager
  sidekiq_batch :import_batch do |batch|
    batch.description = "Import KeyGroup #{id} (#{project.name} - #{key})"
    batch.on :success, ImportFinisherForKeyGroups, key_group_id: id
  end

  # ======== START LOCALE RELATED CODE =================================================================================
  validates :base_rfc5646_locale, format: { with: Locale::RFC5646_FORMAT, allow_nil: true }
  set_nil_if_blank :base_rfc5646_locale

  include CommonLocaleLogic

  # If base_locale is set in this KeyGroup, it returns that field.
  # Otherwise, it returns the base_locale of the Project.
  #
  # @return [Hash<Locale, Boolean>] locale requirements for this KeyGroup

  def base_locale_with_inheriting
    base_locale_without_inheriting || project.base_locale
  end

  # If locale_requirements are set in this KeyGroup, it returns that field.
  # Otherwise, it returns the locale_requirements of the Project.
  #
  # @return [Hash<Locale, Boolean>] locale requirements for this KeyGroup

  def locale_requirements_with_inheriting
    # since `targeted_rfc5646_locales` can be an empty hash, we need to check for presence here instead of checking for nil
    locale_requirements_without_inheriting.present? ? locale_requirements_without_inheriting : project.locale_requirements
  end

  # Inherit base_locale from Project if none is provided in this KeyGroup
  alias_method_chain(:base_locale, :inheriting)

  # Inherit locale_requirements from Project if none are provided in this KeyGroup
  alias_method_chain(:locale_requirements, :inheriting)

  # ======== END LOCALE RELATED CODE ===================================================================================


  # ======== START KEY & READINESS RELATED CODE ========================================================================

  # Finds the KeyGroup using its `key` field, in an efficient way.
  # Efficiency comes from the fact that we are searching with the `key_sha_raw` field,
  # and there is an index on that field.
  #
  # May be worth considering putting this kind of support in the DigestField module
  #
  # @param [String] k the string key to find KeyGroup with
  # @return [Key, nil] the {KeyGroup} corresponding to the given key `k`, if any.

  def self.find_by_key(k)
    for_key(k).last if k
  end

  # This filters out the Keys under this KeyGroup which were once an active part of this
  # KeyGroup, but are not anymore. `index_in_key_group` is used as a flag of activeness.
  #
  # @return [Array<Key>] the {Key Keys} that are actively related to this KeyGroup.

  def active_keys
    keys.where("keys.index_in_key_group IS NOT NULL")
  end

  # This filters out the Translations for Keys which don't have their `index_in_key_group` set.
  # If `index_in_key_group` is nil, it means that that translation is not in use.
  #
  # @return [Array<Translation>] the {Translation Translations} that are actively related to this KeyGroup.

  def active_translations
    translations.where("keys.index_in_key_group IS NOT NULL")
  end

  # @return [Collection<Key>] the {Key Keys} under this {KeyGroup} in a sorted fashion.
  #     {Translation Translations} will be `included` in the query.
  #
  # @example
  #   [<Key 1: 0:a>, <Key 2: 1:b>, <Key 3: 2:c>, <Key 4: 10:d>]

  def sorted_active_keys_with_translations
    active_keys.order(:index_in_key_group).includes(:translations)
  end

  # Calculates the value of the `ready` field and saves the record.
  def recalculate_ready!
    keys_are_ready = !active_keys.where(ready: false).exists?
    if !ready? && keys_are_ready # if it just became ready
      self.last_completed_at = Time.current
      self.first_completed_at ||= self.last_completed_at
    end
    self.ready = keys_are_ready
    save!
  end

  # Resets ready fields for this KeyGroup and its Keys.
  # It's necessary to call this after an import is scheduled, and after it's started.
  def reset_ready!
    update!(ready: false) if ready?
    keys.each { |key| key.update!(ready: false) if key.ready? }
  end

  # For any key and any locale in targeted locales (required or not), the key cannot be skipped.
  # For any key and any locale not in targeted locales, the key can be skipped.
  #
  # @param [String] key that will be checked for skipping
  # @param [Locale] locale
  # @return [Boolean] true if the given `key` should be skipped for the given `locale`
  #       in this KeyGroups's context. false, otherwise.

  def skip_key?(key, locale)
    !targeted_locales.include?(locale)
  end

  # ======== END KEY & READINESS RELATED CODE ========================================================================


  # ======== START IMPORT RELATED CODE =================================================================================
  # This is the point of entry for the import process of a KeyGroup.
  # If anything changes related to this KeyGroup which may require a re-import,
  # such as `source_copy` changes or locale settings changes, this method is called.
  #
  # Schedules a KeyGroupImporter to do the actual import.
  #
  # It resets the ready fields of this KeyGroup and associated Keys to false
  # because some important change must have happened to kick off importing, and
  # we cannot guarantee that the KeyGroup or its Keys are ready any more.
  #
  # Updates import_requested_at timestamps.

  def import!
    raise KeyGroup::LastImportNotFinished unless last_import_finished?
    update_import_requested_at!
    reset_ready!
    KeyGroupImporter.perform_once(id)
  end

  # Updates first and last import_requested_at fields.
  # Called only in a key_group's `import!` method
  # @private

  def update_import_requested_at!
    new_attrs = {last_import_requested_at: Time.current}
    new_attrs[:first_import_requested_at] = new_attrs[:last_import_requested_at] unless first_import_requested_at
    self.update!(new_attrs)
  end
  private :update_import_requested_at!

  # Called only in the Importer::KeyGroup's `import_strings` method,
  # at the start of an import job.
  #
  # Clears the `import_batch_id` so that we can force re-import a hanging KeyGroup import.
  #
  # Loading is set to true and ready is set to false.
  #
  # First and last import_started_at timestamps are also updated as necessary.

  def update_import_starting_fields!
    new_attrs = { loading: true, import_batch_id: nil, ready: false, last_import_started_at: Time.current }
    new_attrs[:first_import_started_at] = new_attrs[:last_import_started_at] unless first_import_started_at
    update!(new_attrs)
  end

  # Called only in the ImportFinisherForKeyGroups's `on_success` method,
  # at the end of an import job.
  #
  # Clears the `import_batch_id` because we are done with that batch id and should not re-use it.
  #
  # Loading is set to false.
  #
  # First and last import_finished_at timestamps are also updated as necessary.

  def update_import_finishing_fields!
    new_attrs = { loading: false, import_batch_id: nil, last_import_finished_at: Time.current }
    new_attrs[:first_import_finished_at] = new_attrs[:last_import_finished_at] unless first_import_finished_at
    update!(new_attrs)
  end

  # The last scheduled import is considered finished if the import has started and finished successfully.
  # If the import is scheduled but didn't start yet, it's considered 'not finished'.
  # If the import is scheduled and started, it's also considered 'not finished'.
  #
  # @return [true, false] true if the last scheduled import has been finished,
  #                       false otherwise.
  def last_import_finished?
    !last_import_requested_at || ( !!last_import_finished_at && ( last_import_finished_at >= last_import_requested_at))
  end

  # ======== END IMPORT RELATED CODE ===================================================================================

  # ======== START ERRORS RELATED CODE =================================================================================
  # Raised when a re-import is called on a KeyGroup before the previous import didn't finish yet.
  class LastImportNotFinished < StandardError
  end
  # ======== END ERRORS RELATED CODE ===================================================================================

end
