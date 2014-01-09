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

# Overrides Devise's registrations controller to redirect to the login page
# after a user signs up, and work with strong parameters.

class RegistrationsController < Devise::RegistrationsController

  def create
    build_resource(sign_up_params)

    if resource.save
      if resource.active_for_authentication?
        set_flash_message :notice, :signed_up if is_navigational_format?
        sign_up(resource_name, resource)
        respond_with resource, :location => after_sign_up_path_for(resource)
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_navigational_format?
        expire_session_data_after_sign_in!
        respond_with resource, :location => after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      redirect_to new_user_session_url(:anchor => "sign-up"), 
        alert: resource.errors.full_messages.unshift("Unable to create account")
    end
  end

  protected

  # @private
  def after_inactive_sign_up_path_for(resource)
    new_user_session_url
  end

  # @private
  def sign_up_params
    params.require(:user).permit(:email, :first_name, :last_name, :password,
                                 :password_confirmation)
  end

  # @private
  def account_update_params
    params.require(:user).permit(:first_name, :last_name, :password,
                                 :password_confirmation)
  end
end
