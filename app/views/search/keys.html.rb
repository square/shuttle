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
    class Keys < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          ul(class: 'nav nav-tabs') do
            li { a "Translations", href: search_translations_url }
            li(class: 'active') { a "Keys", href: search_keys_url }
          end
          div(class: 'tab-content') do
            key_search_bar
            key_grid
          end
        end
      end

      def active_tab() 'search' end

      private

      def key_search_bar
        form_tag(search_keys_url(format: 'json'), method: 'GET', id: 'key-search-form', class: 'filter form-inline') do
          text "Show me "
          select_tag 'filter', options_for_select(
              [
                  ['all', nil],
                  ['untranslated', 'untranslated'],
                  ['translated but not approved', 'unapproved'],
                  ['approved', 'approved']
              ]
          ),         id: 'key-filter-select'

          text " translations in project "
          project_list = Project.order('LOWER(name) ASC').map { |pr| [pr.name, pr.id] }
          select_tag 'project_id', options_for_select(project_list)

          text " with key substring "
          text_field_tag 'filter', '', placeholder: 'filter by key', id: 'key-filter-field'
          text ' '
          submit_tag "Filter", class: 'btn btn-primary'
        end
      end

      def key_grid
        table class:         'table table-striped',
              id:            'keys',
              'data-url'     => search_keys_url(format: 'json')
      end
    end
  end
end
