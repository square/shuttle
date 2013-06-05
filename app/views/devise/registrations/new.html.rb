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
  module Devise
    module Registrations
      class New < Views::Layouts::Application
        protected

        def body_content
          article(class: 'container') do
            page_header "Sign up"
            rawtext devise_error_messages!
            form_for(resource, as: resource_name, url: registration_path(resource_name), html: {class: 'form-horizontal'}) do |f|
              div(class: 'control-group') do
                f.label :email, class: 'control-label'
                div(class: 'controls') do
                  f.email_field :email, required: true
                end
              end

              div(class: 'control-group') do
                f.label :first_name, "Name", class: 'control-label'
                div(class: 'controls') do
                  f.text_field :first_name, required: true
                  f.text_field :last_name, required: true
                end
              end

              div(class: 'control-group') do
                f.label :password, class: 'control-label'
                div(class: 'controls') do
                  f.password_field :password, required: true
                end
              end

              div(class: 'control-group') do
                f.label :password_confirmation, class: 'control-label'
                div(class: 'controls') do
                  f.password_field :password_confirmation, required: true
                end
              end

              div(class: 'form-actions') do
                f.submit class: 'btn btn-primary'
              end
            end

            devise_links
          end
        end
      end
    end
  end
end
