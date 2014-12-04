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

# Represents a unique identifier for a translatable string in a Project. The
# actual content of a key depends on the localization library used by that
# project.
#
# A Key has one base Translation, whose locale matches the Project's base
# locale, and zero or more sibling Translations in the other locales supported
# by the Project. When Translations in all required Locales are marked as
# approved, the Key is marked as ready. When all Keys applicable to a
# Commit/KeyGroup are marked as ready, the Commit/KeyGroup is marked as ready.
#
# Key uniqueness
# --------------
#
# A key must be unique to a Project (at the time of a specific Commit). However,
# it is not the case in all i18n libraries that a key is unique. For example,
# Android allows multiple strings to share the same key so long as they appear
# under different "qualifiers" (device properties); e.g., two strings can share
# a key if one is for landscape and the other for portrait orientations.
#
# To deal with this, this type of metadata is serialized into the `key` field
# (and therefore represented in the `key_sha_raw` column, on which uniqueness is
# enforced). The original value of the key without this metadata is written to
# the `original_key` field.
#
# Source copy
# -----------
#
# Keys are uniquely referenced in combination with their source copy; in other
# words, when a key's source copy changes, a new Key is generated.
#
#
# Keys that belong to a KeyGroup
# ------------------------------
#
# A key may belong_to a KeyGroup through the key_group_id column
# (in which case, it will not belong to a commit or blob).
#
# If `index_in_key_group` is set, it means that this {Key} is an active part of
# this {KeyGroup}. If set, it shows its order in all of KeyGroup's Keys.
# In that sense, this field serves 2 purposes: a flag for active or not, and keeps
# the order info. If null, it means this Key is not actively used in the KeyGroup;
# if set, it's actively used in the KeyGroup.
#
# The key field of {Key} will be in this format: `index_in_key_group:source_copy_sha`.
#   - index_in_key_group is included because if a paragraph is repeated twice in the KeyGroup,
#     we should create 2 separate {Key Keys} for them, with unique key names.
#     When re-importing a KeyGroup, we may deactivate a Key in a KeyGroup by removing
#     the `index_in_key_group` field.
#     When that happens, it's important to store the index in the `key` field, because
#     the deactivated {Key} can be activated again, and we would search by the `key` field
#     of {Key}.
#     And it's less error-prone to store the index in the `key` field all the time rather than
#     only when deactivating a Key.
#   - source_copy_sha is included because we need a predictable `key` field, so that we can
#     search by it later. source_copy_sha is the most obvious solution for that.
#
#
# If the {Key} belongs to a KeyGroup, `key` field of {Key} is unique in combination with
# the KeyGroup id.
#
# Associations
# ============
#
# |                |                                                                           |
# |:---------------|:--------------------------------------------------------------------------|
# | `project`      | The {Project} this Key belongs to.                                        |
# | `translations` | The {Translation Translations} of this Key's copy into different locales. |
# | `commits`      | The {Commit Commits} this Key can be found in.                            |
# | `blobs`        | The {Blob Blobs} this Key can be found in.                                |
# | `key_group`    | The {KeyGroup KeyGroup} this Key belongs to.                              |
#
# Fields
# ======
#
# |                      |                                                                                                                          |
# |:---------------------|:-------------------------------------------------------------------------------------------------------------------------|
# | `ready`              | `true` when every required Translation under this Key has been approved.                                                 |
# | `index_in_key_group` | index of this {Key} in the {KeyGroup} with respect to other {Key Keys}.                                                  |
# | `key`                | The identifier for this string in the project's code, potentially with serialized metadata to ensure uniqueness.         |
# | `original_key`       | The identifier for this string in the project's code, as it originally appeared in the code.                             |
# | `source_copy`        | The original source copy of the key. Used to ensure that a new Key is generated if the source copy changes.              |
# | `context`            | A human-readable contextual description of the string, from the program's code.                                          |
# | `importer`           | The name of the {Importer::Base} subclass that created the Key.                                                          |
# | `source`             | The path to the project file where the base string was found.                                                            |
# | `fencers`            | An array of fencers that should be applied to the Translations of this string.                                           |
# | `other_data`         | A hash of importer-specific information applied to the string. Not used by anyone except possible the importer/exporter. |

class Key < ActiveRecord::Base
  belongs_to :project, inverse_of: :keys
  has_many :translations, inverse_of: :key, dependent: :destroy
  has_many :commits_keys, inverse_of: :key, dependent: :destroy
  has_many :commits, through: :commits_keys
  has_many :blobs_keys, dependent: :delete_all, inverse_of: :key
  has_many :blobs, through: :blobs_keys
  belongs_to :key_group, inverse_of: :keys

  include InheritedSettingsForKey

  serialize :fencers, Array
  serialize :other_data, Hash

  before_validation { |obj| obj.source_copy = '' if obj.source_copy.nil? }
  before_validation(on: :create) { |obj| obj.original_key ||= obj.key }
  validates :key, :original_key, presence: true

  # @return [true, false] If `true`, the after-save hooks that recalculate
  #   Commit `ready?` values will not be run. You should use this when
  #   processing a large batch of Keys.
  attr_accessor :skip_readiness_hooks

  # @private
  attr_accessor :batched_commit_ids

  def apply_readiness_hooks?() !skip_readiness_hooks end
  private :apply_readiness_hooks?

  extend DigestField
  digest_field :key, scope: :for_key
  digest_field :source_copy, scope: :source_copy_matches

  include Tire::Model::Search
  include Tire::Model::Callbacks
  settings analysis: {tokenizer: {key_tokenizer: {type: 'pattern', pattern: '[^A-Za-z0-9]'}},
           analyzer: {key_analyzer: {type: 'custom', tokenizer: 'key_tokenizer', filter: 'lowercase'}}}
  mapping do
    indexes :original_key, type: 'multi_field', as: 'original_key', fields: {
        original_key:       {type: 'string', analyzer: 'key_analyzer'},
        original_key_exact: {type: 'string', index: :not_analyzed}
    }
    indexes :project_id, type: 'integer'
    indexes :ready, type: 'boolean'
    indexes :commit_ids, as: 'batched_commit_ids.try!(:to_a) || commits_keys.pluck(:commit_id)'
  end

  validates :project,
            presence: true
  validates :source_copy_sha_raw,
            presence:   true
  validates :key_sha_raw,
            presence:   true
  validates :key_sha_raw,
            uniqueness: {scope: [:project_id, :source_copy_sha_raw], if: "key_group_id.nil?", on: :create}
  validates :key_sha_raw,
            uniqueness: {scope: [:key_group_id], if: "key_group_id", on: :create}
  validates :index_in_key_group,
            uniqueness: {scope: [:key_group_id], if: "key_group_id && index_in_key_group", on: :create}

  attr_readonly :project_id, :source_copy

  scope :in_blob, ->(blob) { where(project_id: blob.project_id, sha_raw: blob.sha_raw) }

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :source_fences << :fences << :original_key << :key
    options[:methods] << :importer_name

    options[:except] = Array.wrap(options[:except])
    options[:except] << :key_sha_raw << :searchable_key
    options[:except] << :project_id
    options[:except] << :source_copy_sha_raw

    super options
  end

  # @return [Class] The {Importer::Base} subclass that performed the import.
  def importer_class() Importer::Base.find_by_ident(importer) end

  # @return [String] The human-readable name for the importer.
  def importer_name() importer_class.human_name end

  # Scans all of the base Translations under this Key and adds Translations for
  # each of the required locales and base locale where such a Translation
  # does not already exist.
  #
  # If this key is associated with a key_group, base_locale and targeted_locales are
  # retrieved from the KeyGroup. Otherwise, they are retrieved from Project.
  #
  # This is used, for example, when a Project adds a new required localization,
  # to create pending Translation requests for each string in the new locale.

  def add_pending_translations
    translations.in_locale(base_locale).find_or_create!(
        source_copy:              source_copy,
        copy:                     source_copy,
        source_locale:            base_locale,
        locale:                   base_locale,
        approved:                 true,
        preserve_reviewed_status: true,
    )

    targeted_locales.each do |locale|
      next if skip_key?(locale)
      translations.in_locale(locale).find_or_create!(
        source_copy:          source_copy,
        source_locale:        base_locale,
        locale:               locale,
      )
    end
  end

  # Scans all of the Translations under this Tree and removes translations that
  # should be excluded based on the Project's `key_*clusions` and
  # `key_locale_*clusions`, or KeyGroup's targeted locales.
  # Translations that have been translated or approved are never removed,
  # only pending Translations.

  def remove_excluded_pending_translations
    translations.not_base.not_translated.where(approved: nil).find_each do |translation|
      if skip_key?(translation.locale) || !targeted_locales.include?(translation.locale)
        translation.destroy
      end
    end
  end

  # Recalculates the value of the `ready` column and updates the record.

  def recalculate_ready!
    new_ready = should_become_ready?
    return if new_ready == ready # proceed only if ready is about to change
    update ready: new_ready
    KeyAncestorsRecalculator.perform_once(id) unless skip_readiness_hooks
  end

  # @return [true, false] `true` if this Key should now be marked as ready.

  def should_become_ready?
    if translations.loaded?
      translations.select { |t| required_locales.include?(t.locale) }.all?(&:approved?)
    else
      !translations.in_locale(*required_locales).where('approved IS NOT TRUE').exists?
    end
  end

  # This takes a Commit, a Project or a KeyGroup, and batch updates their readiness states.
  # Called in CommitImporter::Finisher and ProjectTranslationsAdderAndRemover::Finisher at the moment.
  #
  # @param [Commit, Project, KeyGroup] obj The object whose keys should be batch recalculated

  def self.batch_recalculate_ready!(obj)
    # TODO (yunus): look into speeding this up
    ready_keys, not_ready_keys = obj.keys.includes(:project, :translations).partition(&:should_become_ready?)
    ready_keys.in_groups_of(500, false) { |group| Key.where(id: group.map(&:id)).update_all(ready: true) }
    not_ready_keys.in_groups_of(500, false) { |group| Key.where(id: group.map(&:id)).update_all(ready: false) }

    # Since update_all bypasses all callbacks, `ready` field for some Keys should be out of sync in ElasticSearch at this point.
    # We need to update ElasticSearch with the new ready fields.
    # We can just run `Key.tire.index.import obj.keys`, however this would be slow because it needs to find
    # commit_ids for each Key. Instead, we can preload all the commits_keys for all commits,
    # and partition them into the correct commits.
    obj.keys.find_in_batches do |keys|
      commits_by_key = CommitsKey.connection.select_rows(CommitsKey.select('commit_id, key_id').where(key_id: keys.map(&:id)).to_sql).inject({}) do |hsh, (commit_id, key_id)|
        hsh[key_id.to_i] ||= Set.new
        hsh[key_id.to_i] << commit_id.to_i
        hsh
      end
      # now set batched_commit_ids for each key
      keys.each { |key| key.batched_commit_ids = commits_by_key[key.id] || Set.new }
      # and run the import
      Key.tire.index.import keys
    end
  end

  # @private
  def inspect(default_behavior=false)
    return super() if default_behavior
    state = ready? ? 'ready' : 'not ready'
    "#<#{self.class.to_s} #{id}: #{key} (#{state})>"
  end
end
