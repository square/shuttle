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

# encoding: utf-8

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module Users
    class Index < Views::Layouts::Application
      needs :users

      protected

      def body_content
        article(class: 'container') do
          page_header "Users"
          users_list
        end
      end

      def active_tab() 'users' end

      private

      def users_list
        table(class: 'table') do
          thead do
            tr do
              th "Email"
              th "Name"
              th "Role"
            end
          end

          tbody do
            @users.each do |user|
              tr do
                td { link_to user.email, user_url(user) }
                td user.name
                td do
                  if user.role?
                    text t("models.user.role.#{user.role}")
                  else
                    span "unauthorized", class: 'label label-info'
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
