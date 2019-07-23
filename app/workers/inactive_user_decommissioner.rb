# Copyright 2016 Square Inc.
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

# This workder puts ex-Squarer into expired state to prevent them from accessing Shuttle.
# The expired users can use Forgot Password to re-activate their accounts.
class InactiveUserDecommissioner
  include Sidekiq::Worker
  sidekiq_options queue: :high, retry: false

  def perform
    report_message('started')

    # Retrieves domain users
    decomission_inactive_user_url = Shuttle::Configuration.features[:decomission_inactive_user_url]
    decomission_inactive_user_domain = Shuttle::Configuration.features[:decomission_inactive_user_domain]

    ldap_user_response = HTTParty.get(Shuttle::Configuration.features[:decomission_inactive_user_url])
    unless ldap_user_response.code == 200
      report_message("Failed to retrieve LDAP users. error code: #{ldap_user_response.code}")
      return
    end

    ldap_user_details = ldap_user_response.parsed_response
    active_user_details = ldap_user_details.reject { |u| u['state'] == 'disabled' }
    if active_user_details.count < 3000
      # Stop processing in case LDAP returns empty or partial accounts back.
      # This will avoid putting all Square users into expired state.
      report_message("Found #{active_user_details.count} active LDAP users. Skip processing because of too few.")
      return
    end
    active_user_names = active_user_details.map { |detail| detail['username'] }

    # Finds non-expired non-domain accounts
    shuttle_users = User.where("email like '%#{decomission_inactive_user_domain}'")
    inactive_shuttle_users = shuttle_users.reject do |user|
      email = user.email.downcase

      email_domains = email.split('@')
      raise "Not expected domain user #{user.id}" unless email_domains.count == 2 and email_domains[1] == decomission_inactive_user_domain

      email_users = email_domains[0].split('+')
      user.expired? || active_user_names.include?(email_users[0])
    end

    # Puts the inactive accounts as expired.
    inactive_shuttle_users.each do |inactive_user|
      report_message("Inactivate user #{inactive_user.email}")
      inactive_user.update(last_activity_at: User.expire_after.ago)
    end
  end

  def report_message(message)
    Rails.logger.info("InactiveUserDecommissioner - #{message}")
  end

  include SidekiqLocking
end
