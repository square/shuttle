# Copyright 2018 Square Inc.
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

class Asset < ActiveRecord::Base
  belongs_to :project,    inverse_of: :assets
  belongs_to :user
  has_many :assets_keys, inverse_of: :asset, dependent: :delete_all
  has_many :keys, through: :assets_keys
  has_many :translations, through: :keys

  scope :hidden, -> { where(hidden: true) }
  scope :showing, -> { where(hidden: false) }
  scope :ready, -> { where(ready: true) }
  scope :not_ready, -> { where(ready: false) }

  FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED = %w(file targeted_rfc5646_locales)
  CONTENT_TYPES = [
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]

  has_attached_file :file

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :name, exclusion: { in: %w(new) } # this word is reserved because it collides with new_asset_path.
  validates_attachment :file, presence: true, content_type: { content_type: CONTENT_TYPES }
  validates :file_name, presence: true


  include ArticleOrCommitStats
  alias_method :active_translations, :translations # called in ArticleOrCommitStats
  alias_method :active_keys, :keys # called in ArticleOrCommitStats
  # alias_method :active_issues, :issues # called in ArticleOrCommitIssuesPresenter

  # ======== START LOCALE RELATED CODE =================================================================================
  include CommonLocaleLogic
  before_validation(on: :create) do |asset|
    if asset.project # this is needed to test validate_attachment_presence, project is null in this case for some reason
      asset.base_rfc5646_locale      = asset.project.base_rfc5646_locale if asset.base_rfc5646_locale.blank?
      asset.targeted_rfc5646_locales = asset.project.targeted_rfc5646_locales if asset.targeted_rfc5646_locales.blank?
    end
  end
  # ======== END LOCALE RELATED CODE ===================================================================================

  extend SetNilIfBlank
  set_nil_if_blank :description, :due_date, :priority

  # Add import_batch and import_batch_status methods
  extend SidekiqBatchManager
  sidekiq_batch :import_batch do |batch|
    batch.description = "Import Asset #{id} (#{project.name} - #{name})"
    batch.on :success, AssetImporter::Finisher, asset_id: id
  end

  def update_import_starting_fields!
    update!(ready: false, loading: true)
  end

  def update_import_finishing_fields!
    new_attrs = { import_batch_id: nil, loading: false }
    update!(new_attrs)
  end

  # Calculates the value of the `ready` field and saves the record.
  def recalculate_ready!
    self.ready = !loading && keys_are_ready?
    self.approved_at = Time.current if self.ready && self.approved_at.nil?
    save!
  end

  # Resets ready fields for this Asset and its Keys.
  # It's necessary to call this after an import is scheduled, and after it's started.
  def full_reset_ready!
    update!(ready: false) if ready?
    keys.update_all(ready: false)
  end

  # Returns `true` if all Keys associated with this commit are ready.
  #
  # @return [true, false] Whether all keys are ready for this commit.

  def keys_are_ready?
    !keys.where(ready: false).exists?
  end

  def import!(force_import_sections=false)
    raise Asset::LastImportNotFinished if loading?
    full_reset_ready! # reset ready immediately without waiting for the AssetImporter job to be processed
    import_batch.jobs { AssetImporter.perform_once(id) }
  end

  class LastImportNotFinished < StandardError
  end
end
