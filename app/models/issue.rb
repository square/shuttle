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
# |                     |                                                                                                                     |
# |:--------------------|:--------------------------------------------------------------------------------------------------------------------|
# | `summary`           | A brief summary of the issue.                                                                                       |
# | `description`       | Detailed description of the issue.                                                                                  |
# | `priority`          | An integer in range [-1..3] that represent the priority of the issue.                                               |
# | `kind`              | An integer in range [1..6] that represents the kind of the issue.                                                   |
# | `status`            | An integer in range [1..4] that represents the state of the issue. (Ex: 1 represents 'Open'). Set to 1 on creation. |
# | `subscribed_emails` | An array email addresses to notify after an issue is created or updated.                                            |

class Issue < ActiveRecord::Base

  module Status
    OPEN = 1
    IN_PROGRESS = 2
    RESOLVED = 3
    ICEBOX = 4
  end

  SKIPPED_FIELDS_FOR_EMAIL_ON_UPDATE = %w(created_at updated_at)

  belongs_to :translation, inverse_of: :issues
  belongs_to :user, inverse_of: :issues
  belongs_to :updater, class_name: User
  has_many :comments, inverse_of: :issue, dependent: :delete_all
  delegate :project, to: :key
  delegate :key, to: :translation

  validates :user, presence: {on: :create} # in case the user gets deleted afterwards
  validates :updater, :translation, presence: true
  validates :summary, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :priority, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3}, allow_nil: true
  validates :kind, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 6}
  validates :status, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 4}

  before_validation(on: :create) { self.status = Status::OPEN }


  def self.new_with_defaults
    new(subscribed_emails: [Shuttle::Configuration.mailer.translators_list])
  end

  # ===== START SCOPES BY STATUS =====
  scope :pending, -> { where(status: [Status::OPEN, Status::IN_PROGRESS]) }

  def pending?
    status == Status::OPEN or status == Status::IN_PROGRESS
  end
  # ===== END SCOPES BY STATUS =====

  # ===== START subscribed_emails =====
  serialize :subscribed_emails, Array
  validate :subscribed_emails_format

  def subscribed_emails=(emails)
    if !emails
      emails = []
    elsif emails.is_a?(String)
      emails = emails.split(",")
    end
    emails = emails.map(&:strip).map(&:presence).compact.uniq
    write_attribute(:subscribed_emails, emails)
  end

  # Adds the given email to the subscribed emails list
  # Updates the record in the database without calling validations or callbacks
  #  @param [String] email that will be subscribed

  def subscribe_email_silently(email)
    self.subscribed_emails += [email] # so that this calls `subscribed_emails=` which does the sanitation
    subscribed_emails_format
    update_column :subscribed_emails, subscribed_emails unless errors.any?
  end

  def subscribed_emails_format
    if subscribed_emails
      subscribed_emails.each do |email|
        unless email =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
          errors.add(:subscribed_email, I18n.t('errors.messages.invalid_email', email: email))
        end
      end
    end
  end
  private :subscribed_emails_format
  # ===== END subscribed_emails =====

  def user_name
    user.try!(:name) || t('models.issue.unknown_user')
  end

  def self.order_default
    order('issues.status ASC, issues.priority ASC, issues.created_at DESC')
  end
end
