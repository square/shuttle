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

# Represents a group of {Article Articles}, and provides a thin layer of abstraction over them.
#
# Name uniqueness
# --------------
#
# The `name` field of Group is treated as a unique identifier within a Project.
#
# Associations
# ============
#
# |                |                                                            |
# |:---------------|:-----------------------------------------------------------|
# | `project`      | The {Project} this Group belongs to                        |
# | `articles`     | The {Article Articless} that belong to this Group          |
#
# Fields
# ======
#
# |                             |                                                                                                                   |
# |:----------------------------|:------------------------------------------------------------------------------------------------------------------|
# | `name`                      | The unique identifier for this Group. This will be a user input in most cases.                                    |
# | `description`               | A user submitted description. Can be used to provide context or instructions.                                     |
# | `email`                     | The email address that should be used for communications.                                                         |
# | `ready`                     | `true` when every required Translation under this Article has been approved.                                      |
# | `priority`                  | An priority defined as a number between 0 (highest) and 3 (lowest).                                               |
# | `due_date`                  | A date displayed to translators and reviewers informing them of when the Group must be fully localized.           |

class Group < ActiveRecord::Base
  extend SetNilIfBlank
  set_nil_if_blank :description, :due_date, :priority

  belongs_to :creator,    class_name: 'User'
  belongs_to :updater,    class_name: 'User'
  belongs_to :project,    inverse_of: :groups

  has_many :article_groups, inverse_of: :group, dependent: :destroy
  has_many :articles, through: :article_groups

  # Scopes
  scope :hidden, -> { where(hidden: true) }
  scope :showing, -> { where(hidden: false) }
  scope :ready, -> { where(ready: true) }
  scope :not_ready, -> { where(ready: false) }
  scope :loading, -> { where(loading: true) }

  attr_readonly :project_id

  validates :project, presence: true, strict: true
  validates :name, presence: true, uniqueness: {scope: :project_id}
  validates :name, exclusion: { in: %w(new) } # this word is reserved because it collides with new_group_path.
  validates :description, length: {maximum: 2000}, allow_nil: true
  validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }, allow_nil: true
  validates :ready,   inclusion: { in: [true, false] }, strict: true
  validates :priority, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3}, allow_nil: true
  validates :due_date, timeliness: {type: :date}, allow_nil: true

  delegate :required_locales, :required_rfc5646_locales, :targeted_rfc5646_locales, :locale_requirements, to: :project

  def to_param() name end
end
