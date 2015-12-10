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

# A user of this application. Users are identified by their email address and
# authenticated with a password. Authentication is handled by Devise.
#
# Users become `activated` by confirming their email address and getting assigned a role.
#
# Users can have one of four roles:
#
# **Translators** can view localizable strings and contribute translations to
# those strings in the locales they are comfortable with.
#
# **Reviewers** can view localized strings and approve or reject them.
#
# **Engineers** can specify commits that need translation and create custom
# translation requests.
#
# **Administrators** can add Projects and edit their settings, track the
# progress of internationalization, and approve new User accounts.
# Administrators also have the same privileges as all other roles.
#
# Associations
# ============
#
# |                         |                                                                              |
# |:------------------------|:-----------------------------------------------------------------------------|
# | `authored_translations` | The {Translation Translations} this User has contributed.                    |
# | `reviewed_translations` | The {Translation Translations} this User has approved or rejected.           |
# | `commits`               | All {Commit Commits} submitted by this User for translation.                 |
# | `issues`                | All {Issue Issues} reported by this User.                                    |
# | `comments`              | All {Comment Comments} written by this User.                                 |
#
# Properties
# ==========
#
# |                    |                                                                                                              |
# |:-------------------|:-------------------------------------------------------------------------------------------------------------|
# | `role`             | This user's role, determining what actions they are authorized to perform. If `nil`, the user is unapproved. |
# | `email`            | The User's email address.                                                                                    |
# | `first_name`       | The User's first name.                                                                                       |
# | `last_name`        | The User's last name.                                                                                        |
# | `approved_locales` | A list of locales that this translator or reviewer is approved to work with.                                 |
#
# There are other columns used by Devise; see the Devise documentation for
# details.

class User < ActiveRecord::Base
  ROLES = %w(monitor translator reviewer admin)

  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable, :lockable

  has_many :authored_translations, class_name: 'Translation', foreign_key: 'translator_id', inverse_of: :translator, dependent: :nullify
  has_many :reviewed_translations, class_name: 'Translation', foreign_key: 'reviewer_id', inverse_of: :reviewer, dependent: :nullify

  has_many :authored_glossary_entries, class_name: 'LocaleGlossaryEntry', foreign_key: 'translator_id', inverse_of: :translator, dependent: :nullify
  has_many :reviewed_glossary_entries, class_name: 'LocaleGlossaryEntry', foreign_key: 'reviewer_id', inverse_of: :reviewer, dependent: :nullify

  has_many :commits, inverse_of: :user, dependent: :nullify
  has_many :issues, inverse_of: :user, dependent: :nullify
  has_many :comments, inverse_of: :user, dependent: :nullify

  serialize :approved_rfc5646_locales, Array

  extend LocaleField
  locale_field :approved_locales,
               from:   :approved_rfc5646_locales,
               reader: ->(values) { values.map { |v| Locale.from_rfc5646 v } },
               writer: ->(values) { values.map(&:rfc5646) }

  validates :first_name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :last_name, presence: true,  length: { minimum: 1, maximum: 100 }
  validates :role, inclusion: {in: ROLES}, allow_nil: true

  extend SetNilIfBlank
  set_nil_if_blank :role

  scope :has_role, -> { where("users.role IS NOT NULL") }
  scope :confirmed, -> { where("users.confirmed_at IS NOT NULL") }
  scope :activated, -> { has_role.confirmed }

  # Updates the user's role to 'monitor' if the user's email address' domain is one of
  # the `domains_to_get_monitor_role_after_email_confirmation` in settings.yml.
  # The reason is that we trust these email addresses, and don't need an admin to
  # activate their accounts.
  # For all other email addresses, admin approval is required for them to use the application.
  def after_confirmation
    privileged_domains = Shuttle::Configuration.app[:domains_to_get_monitor_role_after_email_confirmation]
    if privileged_domains && privileged_domains.include?(email_domain)
      update(role: 'monitor') unless has_role?
    end
  end

  # @private Used by Devise.
  def active_for_authentication?() super && role? end

  # @return [String] The User's full name.
  def name() I18n.t 'models.user.name', first: first_name, last: last_name end
  # @return [String] An abbreviated name for the user.
  def abbreviated_name() I18n.t('models.user.name', first: first_name, last: last_name[0, 1]) end


  ROLES.each do |role|
    define_method(:"#{role}?") { self.role == role || self.role == 'admin' }
  end

  # @private
  def translator?
    %w(translator reviewer admin).include? role
  end

  # @return [String] The URL to the user's Gravatar.
  def gravatar
    "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest email}?s=600"
  end

  # Returns whether or not a translator is allowed to translate in a given
  # locale.
  #
  # @param [Locale, String] locale_id A locale or RFC 5646 code.
  # @return [true, false] Whether the translator is allowed to edit Translations
  #   in that locale.

  def has_access_to_locale?(locale_id)
    locale_id = locale_id.rfc5646 if locale_id.kind_of?(Locale)
    admin? || approved_rfc5646_locales.include?(locale_id.strip)
  end

  # @return [true, false] whether or not the user has permissions to search other users
  def can_search_users?
    allowed_domains = Shuttle::Configuration.app[:domains_who_can_search_users]
    allowed_domains && allowed_domains.include?(email_domain)
  end

  # @return [true, false] whether or not the user has a role and confirmed their email address
  def activated?
    has_role? && confirmed?
  end

  # @return [true, false] whether or not the user has a role
  def has_role?
    role.present?
  end

  # @private
  def as_json(options={})
    options[:except] = Array.wrap(options[:only])
    options[:except] <<  :encrypted_password
    options[:except] <<  :rememember_created_at
    options[:except] <<  :current_sign_in_at
    options[:except] <<  :last_sign_in_at
    options[:except] <<  :current_sign_in_ip
    options[:except] <<  :last_sign_in_ip
    options[:except] <<  :locked_at

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :name

    super options
  end

  # @private
  def to_json(options=nil)
    as_json(options || {}).to_json
  end

  # @private
  def email_domain
    Mail::Address.new(email).domain
  end
end
