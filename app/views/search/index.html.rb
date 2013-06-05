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
  module Search
    class Index < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          page_header "Global Search"
          search_bar
          translation_grid
        end
      end

      def active_tab() 'search' end

      private

      def search_bar
        form_tag(nil, method: 'GET', id: 'search-form', class: 'filter form-inline') do
          text "Find translations whose "
          select_tag 'field', options_for_select([
                                                     ['source copy', 'searchable_source_copy'],
                                                     ['translated copy', 'searchable_copy']
                                                 ]), id: 'field-select', class: 'span2'
          text " contains "
          text_field_tag 'query', '', id: 'search-field'
          text " translated from "
          text_field_tag 'source_locale', 'en', class: 'locale-field span2', id: 'locale-field', placeholder: "any source locale"
          text " to "
          text_field_tag 'target_locales', '', class: 'locale-field locale-field-list span2', id: 'locale-field', placeholder: "any target locale"
          text ' '
          submit_tag "Search", class: 'btn btn-primary'
        end
      end

      def translation_grid
        table class:         'table table-striped',
              id:            'translations',
              'data-url'     => search_url(format: 'json')
      end
    end
  end
end
