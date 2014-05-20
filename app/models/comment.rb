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

# {Comment} represents a comment made by a user for an issue.
#
# Associations
# ============
#
# |         |                                           |
# |:--------|:------------------------------------------|
# | `user`  | The {User} who created the comment.       |
# | `issue` | The {Issue} that this comment belongs to. |
#
# Properties
# ==========
#
# |           |                             |
# |:----------|:----------------------------|
# | `content` | The content of the comment. |

class Comment < ActiveRecord::Base
  belongs_to :user, inverse_of: :comments
  belongs_to :issue, inverse_of: :comments

  validates :user, presence: {on: :create} # in case the user gets deleted afterwards
  validates :issue, presence: true
  validates :content, presence: true, length: { maximum: 1000 }

  def user_name
    user.try!(:name) || t('models.comment.unknown_user')
  end
end
