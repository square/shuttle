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
      needs :commits, :start_date, :end_date, :status

      protected

      def body_content
        article(class: 'container') do
          translation_request_form
          filter_form
          commits_table
          pagination_links
        end
      end

      def translation_request_form
        projects = Project.order('LOWER(name) ASC')
        form_for(Commit.new, url: project_commits_path(projects.first, format: 'json')) do |f|
          label_tag 'new_commit_project_id', Commit.human_attribute_name(:project_id)
          select_tag 'new_commit_project_id', options_for_select(projects.map { |pr| [pr.name, pr.to_param] }), required: true

          f.label :revision
          f.text_field :revision, required: true

          f.label :due_date
          f.date_select :due_date, include_blank: true

          f.label :pull_request_url
          f.text_field :pull_request_url

          f.label :description
          f.text_area :description

          f.submit class: 'btn btn-primary'
        end
      end

      def pagination_links
        p do
          if Commit.where('created_at < ?', @start_date - 2.weeks).exists?
            link_to "« older", url_for(start_date: @start_date - 2.weeks, end_date: @end_date - 2.weeks)
          end
          text ' '
          if @start_date + 2.weeks < Date.today
            link_to "newer »", url_for(start_date: @start_date + 2.weeks, end_date: @end_date + 2.weeks)
          end
        end
      end

      def commits_table
        table(class: 'table', id: 'commits') do
          thead do
            tr do
              th "project"
              th "description"
              th "requester"
              th "pull"
              th "translate"
              th "review"
              th "requested"
              th "due"
              th "priority"
              th "id"
              th "translate" if current_user.translator?
            end
          end

          tbody do
            @commits.each do |commit|
              tbody do
                tr do
                  td commit.project.name
                  td(commit.description || '-')
                  td do
                    if commit.user
                      text! mail_to(commit.user.email)
                    else
                      text '-'
                    end
                  end
                  td do
                    if commit.github_url.present?
                      link_to "code", commit.github_url
                    else
                      text '-'
                    end
                  end
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
                  if current_user.translator?
                    if current_user.approved_locales.any?
                      td do
                        current_user.approved_locales.each do |locale|
                          link_to "#{locale.rfc5646} »", locale_project_url(locale, commit.project, commit: commit.revision)
                        end
                      end
                    else
                      td do
                        input type: 'text', placeholder: 'locale', class: 'locale-field', id: "translate-link-locale-#{commit.revision}"
                        br
                        link_to "translate »", '#',
                                class:         'translate-link',
                                'data-sha'     => commit.revision,
                                'data-project' => commit.project.to_param
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      def filter_form
        form_tag({}, class: 'form-inline', id: 'filter', method: 'get') do
          select_tag 'status', options_for_select(
              %w(all uncompleted completed).map { |n| ["#{n} translations", n] },
              @status
          )

          text ' in '

          project_list = Project.order('LOWER(name) ASC').map { |pr| [pr.name, pr.id] }
          project_list.unshift ['projects in my locales', 'my-locales'] if current_user.approved_locales.any?
          project_list.unshift ['all projects', nil]
          select_tag 'project_id', options_for_select(project_list, params[:project_id])

          if current_user.monitor?
            text ' '
            check_box_tag 'email', current_user.email, params[:email] == current_user.email
            text ' '
            label_tag 'email', 'Only commits submitted by me'
          end

          text ' '

          submit_tag 'Filter', class: 'btn btn-primary'
        end
      end
    end
  end
end
