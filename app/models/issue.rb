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

# {Issue} represents an issue in a {Translation}. Issue's summary, description,
# priority and kind are set by the {User} during creation, and they can be
# updated by anyone later. Issue's status is set to 'Open' on create, and
# can be updated by anyone later.
#
# Associations
# ============
#
# |               |                                                  |
# |:--------------|:-------------------------------------------------|
# | `user`        | The {User} who created the issue.                |
# | `updater`     | The {User} who updated the issue.                |
# | `translation` | The {Translation} that this issue belongs to.    |
# | `comments`    | The {Comment Comments} under this issue.         |
#
# Properties
# ==========
#
# |               |                                                                                                                     |
# |:--------------|:--------------------------------------------------------------------------------------------------------------------|
# | `summary`     | A brief summary of the issue.                                                                                       |
# | `description` | Detailed description of the issue.                                                                                  |
# | `priority`    | An integer in range [-1..3] that represent the priority of the issue.                                               |
# | `kind`        | An integer in range [1..6] that represents the kind of the issue.                                                   |
# | `status`      | An integer in range [1..4] that represents the state of the issue. (Ex: 1 represents 'Open'). Set to 1 on creation. |

class Issue < ActiveRecord::Base

  module Status
    OPEN = 1
    IN_PROGRESS = 2
    RESOLVED = 3
    ICEBOX = 4
  end

  belongs_to :translation, inverse_of: :issues
  belongs_to :user, inverse_of: :issues
  belongs_to :updater, class_name: User
  has_many :comments, inverse_of: :issue, dependent: :delete_all

  validates :user, presence: {on: :create} # in case the user gets deleted afterwards
  validates :updater, :translation, presence: true
  validates :summary, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :priority, numericality: {only_integer: true, greater_than_or_equal_to: -1, less_than_or_equal_to: 3}
  validates :kind, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 6}
  validates :status, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 4}

  before_validation(on: :create) { self.status = Status::OPEN }

  def user_name
    user.try!(:name) || t('models.issue.unknown_user')
  end
end
