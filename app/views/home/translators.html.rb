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
  module Home
    class Translators < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          page_header 'Translate Strings'

          if current_user.approved_rfc5646_locales.present?
            locale_grid
          else
            locale_field
          end

          div id: 'projects'
        end
      end

      def active_tab() 'translate' end

      private

      def locale_grid
        current_user.approved_rfc5646_locales.in_groups_of(2, nil) do |locales|
          div(class: 'row-fluid locale-row') do
            locales.each do |locale|
              if locale
                div(class: 'locale-bubble span6') do
                  a locale, href: '#', class: 'locale-link'
                end
              else
                div(class: 'span6')
              end
            end
          end
        end
      end

      def locale_field
        form(id: 'locale') do
          input type: 'text', name: 'locale', class: 'locale-field', placeholder: 'type a locale here', id: 'locale-field'
          i class: 'icon-refresh spinning', id: 'spinner', style: 'display: none'
        end
      end
    end
  end
end
