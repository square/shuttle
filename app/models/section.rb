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

# Represents a part of an {Article}, where an {Article} can have a lot of {Section Sections}.
#
# Importing
# ---------
#
# SectionImporter handles the importing heavy work. The ArticleImporter
# decides which {Section Sections} to import. As a rule of thumb,
# a {Section} needs to be re-imported when
#   - its `source_copy` changes,
#   - becomes active,
#   - its Article's targeted_rfc5646_locales change
#
# Name uniqueness
# --------------
#
# The `name` field of Article is treated as a unique identifier within an Article.
#
# Activeness
# --------------
#
# A Section will be active when it's first created, but can be inactivated if the Article
# is updated and Article's sections_hash doesn't contain the `name` for this Section anymore.
# If the sections_hash is updated at a later time to include this Section's `name` again,
# the inactivated Section will be activated again.
#
#
# Associations
# ============
#
# |                |                                                            |
# |:---------------|:-----------------------------------------------------------|
# | `project`      | The {Project} this Section belongs to                      |
# | `article`      | The {Section Sections} that belong to this Section         |
# | `keys`         | The {Key Keys} that belong to this Section                 |
# | `translations` | The {Translation Translations} that belong to this Section |
#
# Fields
# ======
#
# |               |                                                                                 |
# |:--------------|:--------------------------------------------------------------------------------|
# | `name`        | The unique identifier for this Section. This will be a user input in most cases |
# | `source_copy` | A user submitted description. Can be used to provide context or instructions    |
# | `active`      | A flag to determine if this Section is active in the Article                    |

class Section < ActiveRecord::Base
  belongs_to :article, inverse_of: :sections
  has_one :project, through: :article
  has_many :keys, inverse_of: :section, dependent: :destroy
  has_many :translations, through: :keys

  extend DigestField
  digest_field :name, scope: :for_name
  digest_field :source_copy, scope: :source_copy_matches

  validates :name, presence: true, uniqueness: { scope: :article_id }
  validates :source_copy, presence: true
  validates :article, presence: true, strict: true
  validates :active, inclusion: { in: [true, false] }, strict: true

  scope :active, -> { where(sections: { active: true }) }
  scope :inactive, -> { where(sections: { active: false }) }


  # @return [Array<Translation>] the {Translation Translations} that are actively related to this Section.

  def active_translations
    translations.merge(Key.active_in_section)
  end

  # This leaves out the Keys which were once an active part of this Section, but are not active anymore.
  # `index_in_section` is used as a flag of activeness.
  #
  # @return [Array<Key>] the {Key Keys} that are actively related to this Section.

  def active_keys
    keys.merge(Key.active_in_section)
  end

  # @return [Collection<Key>] the {Key Keys} under this {Section} in a sorted fashion.
  #     {Translation Translations} will be `included` in the query.
  #
  # @example
  #   [<Key 1: 0:a>, <Key 2: 1:b>, <Key 3: 2:c>, <Key 4: 10:d>]

  def sorted_active_keys_with_translations
    active_keys.order("keys.index_in_section").includes(:translations)
  end
end
