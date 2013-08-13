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
    class Commits < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          ul(class: 'nav nav-tabs') do
            li { a "Translations", href: search_translations_url }
            li { a "Keys", href: search_keys_url }
            li(class: 'active') { a "Commits", href: search_commits_url }
            li { a "Translation Memory", href: translation_units_url } if current_user.reviewer?
          end
          div(class: 'tab-content') do
            commit_search_bar
            commit_grid
          end
        end
      end

      def active_tab() 'search' end

      private

      def commit_search_bar
        form_tag(search_commits_url(format: 'json'), method: :get, id: 'commit-search-form', class: 'filter form-inline') do
          text "Show me commits in project "
          project_list = Project.order('LOWER(name) ASC').map { |pr| [pr.name, pr.id] }
          project_list.unshift ['all', nil]
          select_tag 'project_id', options_for_select(project_list)

          text " with SHA prefix "
          text_field_tag 'sha', '', placeholder: '935ad4', id: 'commit-sha-field'
          text ' '
          submit_tag "Search", class: 'btn btn-primary'
        end
      end

      def commit_grid
        table class:         'table table-striped',
              id:            'commits',
              'data-url'     => search_commits_url(format: 'json')
      end
    end
  end
end
