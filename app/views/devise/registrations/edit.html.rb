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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module Devise
    module Registrations
      class Edit < Views::Layouts::Application
        protected

        def body_content
          article(class: 'container') do
            page_header "Edit #{resource_name.to_s.humanize}"
            rawtext devise_error_messages!
            form_for(resource, as: resource_name, url: registration_path(resource_name), html: {method: :patch, class: 'form-horizontal'}) do |f|
              div(class: 'control-group') do
                f.label :email, class: 'control-label'
                div(class: 'controls') do
                  f.email_field :email
                end
              end

              div(class: 'control-group') do
                f.label :password, class: 'control-label'
                div(class: 'controls') do
                  f.password_field :password
                  p "(leave blank if you don't want to change it)", class: 'help-block'
                end
              end

              div(class: 'control-group') do
                f.label :password_confirmation, class: 'control-label'
                div(class: 'controls') do
                  f.password_field :password_confirmation
                end
              end

              div(class: 'control-group') do
                f.label :current_password, class: 'control-label'
                div(class: 'controls') do
                  f.password_field :current_password
                  p "(we need your current password to confirm your changes)", class: 'help-block'
                end
              end

              div(class: 'form-actions') do
                f.submit "Update", class: 'btn btn-primary'
                button_to "Cancel", :back, class: 'btn'
                button_to "Cancel my account", registration_path(resource_name), class: 'btn btn-danger pull-right', 'data-confirm' => "Are you sure?", 'data-method' => 'delete'
              end
            end
          end
        end
      end
    end
  end
end
