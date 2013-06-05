# Copyright 2013 Square Inc.
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

# @private
module ShuttleDeviseHelper
  protected

  def devise_links
    if controller_name != 'sessions'
      link_to "Sign in", new_session_path(resource_name)
      br
    end

    if devise_mapping.registerable? && controller_name != 'registrations'
      link_to "Sign up", new_registration_path(resource_name)
      br
    end

    if devise_mapping.recoverable? && controller_name != 'passwords'
      link_to "Forgot your password?", new_password_path(resource_name)
      br
    end

    if devise_mapping.confirmable? && controller_name != 'confirmations'
      link_to "Didn't receive confirmation instructions?", new_confirmation_path(resource_name)
      br
    end

    if devise_mapping.lockable? && resource_class.unlock_strategy_enabled?(:email) && controller_name != 'unlocks'
      link_to "Didn't receive unlock instructions?", new_unlock_path(resource_name)
      br
    end

    if devise_mapping.omniauthable?
      resource_class.omniauth_providers.each do |provider|
        link_to "Sign in with #{provider.to_s.titleize}", omniauth_authorize_path(resource_name, provider)
        br
      end
    end
  end
end
