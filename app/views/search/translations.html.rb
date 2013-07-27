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
  module Search
    class Translations < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          ul(class: 'nav nav-tabs') do
            li(class: 'active') { a "Translations", href: search_translations_url }
            li { a "Keys", href: search_keys_url }
          end
          div(class: 'tab-content') do
            translation_search_bar
            translation_grid
          end
        end
      end

      def active_tab() 'search' end

      private

      def translation_search_bar
        form_tag(search_translations_url, method: 'GET', id: 'translation-search-form', class: 'filter form-inline') do
          text 'Find '
          text_field_tag 'query', '', id: 'search-field', placeholder: 'query'
          text ' in '
          select_tag 'field', options_for_select([
                                                     %w(source searchable_source_copy),
                                                     %w(translation searchable_copy),
                                                 ]), id: 'field-select', class: 'span2'
          text ' with translation in '
          if current_user.approved_locales.any?
            select_tag 'target_locales', options_for_select(current_user.approved_locales.map { |l| [l.name, l.rfc5646] })
          else
            text_field_tag 'target_locales', '', class: 'locale-field locale-field-list span2', id: 'locale-field', placeholder: "any target locale"
          end
          text ' for '
          project_list = Project.order('LOWER(name) ASC').map { |pr| [pr.name, pr.id] }
          project_list.unshift ['all', nil]
          select_tag 'project_id', options_for_select(project_list)
          text ' '
          submit_tag "Search", class: 'btn btn-primary'
        end
      end

      def translation_grid
        table class:         'table table-striped',
              id:            'translations',
              'data-url'     => search_translations_url(format: 'json')
      end
    end
  end
end
