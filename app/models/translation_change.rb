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
# | `diff`        | The changes that occured.           |

class TranslationChange < ActiveRecord::Base
  TRACKED_ATTRIBUTES = [:copy, :approved]
  # Reason severity classes, note these must be in order, 0 - 3
  SEVERITY_CLASSES = ['badge-success', 'badge-info', 'badge-warning', 'badge-danger']

  belongs_to :translation, inverse_of: :translation_changes
  belongs_to :user
  belongs_to :project
  belongs_to :article
  belongs_to :asset
  has_many :edit_reasons, dependent: :delete_all
  has_many :reasons, through: :edit_reasons

  serialize :diff, Hash

  validates :translation, presence: true

  enum reason_severities: [:minor, :neutral, :major, :critical]

  scope :latest_changes, -> {
    where("translation_changes.id in (
      SELECT MAX(id) as id
      	FROM translation_changes as tc
      	WHERE tc.role = 'reviewer' AND tc.translation_id = translation_changes.translation_id
      	UNION
      	SELECT MAX(id) as id
      	FROM translation_changes as tc
      	WHERE tc.role = 'translator' AND tc.translation_id = translation_changes.translation_id
      )")
  }

  def self.create_from_translation!(translation)
    create_from_params!(translation, translation.updating_params || {})
  end

  def self.create_from_params!(translation, params)
    diff = translation.previous_changes.slice(*TRACKED_ATTRIBUTES)
    if diff.present?
      project_id = Project.joins(:slugs).where('slugs.slug = ?', params[:project_id]).pluck('projects.id').first
      commit = (params[:commit] == 'Save') ? nil : params[:commit]
      article_id = params[:article_id] || translation.article&.id
      asset_id = params[:asset_id]

      tran = TranslationChange.create(
        translation: translation,
        user: translation.modifier,
        diff: diff,
        role: translation.modifier&.role,
        is_edit: params[:is_edit],
        tm_match: translation.tm_match,
        sha: commit,
        article_id: article_id,
        project_id: project_id,
        asset_id: asset_id,
        reason_severity: params[:reason_severity]
      )
      tran.reason_ids = params[:reason_ids] if params[:reason_ids]
    end
  end

  def as_json(options=nil)
    options ||= {}

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :reasons

    options[:except] = Array.wrap(options[:only])
    options[:except] << :tm_match
    options[:except] << :translation_id
    options[:except] << :project_id

    super options
  end

  def differ
    @differ ||= TranslationDiff.new(diff["copy"][0], diff["copy"][1])
  end

  def compact_copy
    @compact_copy ||= differ.diff
  end
  def compact_copy_from
    diff["copy"].nil? || diff["copy"][0].nil? ? nil : compact_copy[0].strip
  end
  def compact_copy_to
    diff["copy"].nil? || diff["copy"][1].nil? ? nil : compact_copy[1].strip
  end

  def full_copy
    @full_copy ||= differ.aligned
  end
  def full_copy_from
    diff["copy"].nil? || diff["copy"][0].nil? ? nil : full_copy[0]
  end
  def full_copy_to
    diff["copy"].nil? || diff["copy"][1].nil? ? nil : full_copy[1]
  end

  def transition_from
    self.class.status(diff["approved"][0])
  end

  def transition_to
    self.class.status(diff["approved"][1])
  end

  def self.style(approval_status)
    if approval_status.nil?
      "text-info"
    elsif approval_status
      "text-success"
    else
      "text-error"
    end
  end

  def self.status(approval_status)
    if approval_status.nil?
      "Pending"
    elsif approval_status
      "Approved"
    else
      "Rejected"
    end
  end
end
