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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module Devise
    module Unlocks
      class New < Views::Layouts::Application
        protected

        def body_content
          article(class: 'container') do
            page_header "Resend unlock instructions"
            rawtext devise_error_messages!
            form_for(resource, as: resource_name, url: unlock_path(resource_name), html: {method: :post, class: 'form-inline'}) do |f|
              f.label :email
              text ": "
              f.email_field :email
              text ' '
              f.submit "Resend unlock instructions", class: 'btn btn-primary'
            end
            devise_links
          end
        end
      end
    end
  end
end
