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
  module Commits
    class Show < Views::Layouts::Application
      needs :project, :commit, :locales

      protected

      def body_content
        article(class: 'container') do
          page_header do
            h1 "Status of commit #{@commit.revision}"
            button_to 'Delete', project_commit_url(@project, @commit),
                      'data-method' => :delete,
                      id: 'delete_button',
                      'data-confirm' => 'Do you really want to delete this commit?',
                      class: 'btn btn-danger pull-right'
          end
          filter_bar
          translation_grid
        end
      end

      def active_tab() 'admin' end

      private

      def filter_bar
        form_tag(nil, method: 'GET', id: 'filter-form', class: 'filter form-inline') do
          text "Show me "
          select_tag 'status', options_for_select(
              [
                  ['all', nil],
                  ['approved', 'approved'],
                  ['pending', 'pending']
              ]
          ),         id: 'filter-select'
          text " translations with key substring "
          text_field_tag 'filter', '', placeholder: 'filter by key', id: 'filter-field'
          text ' '
          submit_tag "Filter", class: 'btn btn-primary'
        end
      end

      def translation_grid
        table(class:         'table table-striped',
              id:            'translations',
              'data-url'     => project_commit_keys_url(@project, @commit, format: 'json'),
              'data-locales' => @project.targeted_rfc5646_locales.keys.join(',')) do
          thead do
            tr do
              th # key
              @project.locale_requirements.each do |locale, required|
                th(class: required ? 'text-error' : nil) do
                  text locale.rfc5646
                  if @commit.all_translations_approved_for_locale?(locale)
                    text ' '
                    i class: 'icon-ok'
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
