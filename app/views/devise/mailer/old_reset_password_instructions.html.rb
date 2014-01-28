# encoding: utf-8

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

module Views
  module Devise
    module Mailer
      class ResetPasswordInstructions < Erector::Widget
        needs :resource, :token

        def content
          p "Hello #{@resource.email}!"
          p "Someone has requested a link to change your password, and you can do this through the link below."
          p { link_to 'Change my password', edit_password_url(@resource, reset_password_token: @token) }
          p "If you didn't request this, please ignore this email. Your password won't change until you access the link above and create a new one."
        end
      end
    end
  end
end
