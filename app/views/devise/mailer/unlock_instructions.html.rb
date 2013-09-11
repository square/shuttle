# encoding: utf-8

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

module Views
  module Devise
    module Mailer
      class UnlockInstructions < Erector::Widget
        needs :resource

        def content
          p "Hello #{@resource.email}!"
          p "Your account has been locked due to an excessive amount of unsuccessful sign in attempts."
          p "Click the link below to unlock your account:"
          p { link_to 'Unlock my account', unlock_url(@resource, unlock_token: @token) }
        end
      end
    end
  end
end
