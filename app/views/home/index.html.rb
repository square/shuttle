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
    class Index < Views::Layouts::Application
      needs :commits

      protected

      def body_content
        # p "You are not a reviewer, translator, or administrator", class: 'flash-alert alert-info'

        article(class: 'container') do
          page_header "Dashboard"
          div id: 'translation-requests', class: 'task-list'
          table(class: 'table') do
            thead do
              tr do
                th "project"
                th "description"
                th "pull"
                th "translate"
                th "review"
                th "requested"
                th "due"
                th "priority"
                th "id"
              end
            end

            tbody do
              @commits.each do |commit|
                tbody do
                  tr do
                    td commit.project.name
                    td(commit.description || '-')
                    td { link_to "code", commit.github_url }
                    td "#{commit.translations_new}s (#{commit.words_new}w)"
                    td "#{commit.translations_pending}s (#{commit.words_pending}w)"
                    td l(commit.created_at, format: :mon_day)
                    td do
                      if commit.due_date
                        text l(commit.due_date, format: :mon_day)
                      else
                        text '-'
                      end
                    end
                    td do
                      if commit.priority
                        t("models.commit.priority.#{commit.priority}")
                      else
                        text '-'
                      end
                    end
                    td { link_to commit.revision[0, 6], project_commit_url(commit.project, commit) }
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
