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
  module Locale
    module Projects
      class Show < Views::Layouts::Application
        protected

        def body_content
          @mode = params[:mode] || case current_user.role
                                    when 'translator' then 'translation'
                                    else 'review'
                                   end

          article(class: 'container translation-panel') do
            page_header @project.name
            status_line
            filter_bar
            strings
          end
        end

        def active_tab
          case @mode
            when 'translate' then 'translate'
            when 'review' then 'review'
            else nil
          end
        end

        private

        def status_line
          p do
            text "Last imported "
            if (commit = @project.commits.order('committed_at DESC').first)
              strong(time_ago_in_words(commit.committed_at) + " ago")
              text " (commit "
              strong commit.revision[0, 6]
              text ")."
            else
              strong "never"
              text '.'
            end
          end
        end

        def filter_bar
          form(id: 'filter') do
            div(class: 'row-fluid') do
              input type: 'text', name: 'filter', placeholder: 'filter', class: 'span8'
              select_tag 'filter_source', options_for_select([
                                                                 [@locale.name, 'translated'],
                                                                 [@project.base_locale.name, 'source']
                                                             ]), class: 'span2 pull-right'

              preselected_commit = params[:commit].present? ? @project.commits.for_revision(params[:commit]).first : nil
              select_tag 'commit',
                         options_for_select(@project.commits.
                                                order('committed_at DESC').
                                                map { |c| ["#{c.revision[0, 6]}: #{truncate c.message}", c.id] }.
                         unshift(['all commits', nil]), preselected_commit.try(:id))
            end
            div(class: 'row-fluid') do
              div(class: 'form-inline span11') do
                label(class: 'checkbox') do
                  input type: 'checkbox', name: 'include_translated', value: 'true', checked: (@mode == 'review' ? 'checked' : nil)
                  text ' Translated'
                end
                label(class: 'checkbox') do
                  input type: 'checkbox', name: 'include_approved', value: 'true'
                  text ' Approved'
                end
                label(class: 'checkbox') do
                  input type: 'checkbox', name: 'include_new', value: 'true', checked: (@mode == 'translation' ? 'checked' : nil)
                  text ' New'
                end
              end
              submit_tag 'Filter', class: 'btn btn-primary span1 pull-right'
            end
          end
        end

        def strings
          div id: 'strings'
        end

        def completed_sha?(commit)
          if @mode == 'review'
            commit.all_translations_approved_for_locale?(@locale)
          else
            commit.all_translations_entered_for_locale?(@locale)
          end
        end
      end
    end
  end
end
