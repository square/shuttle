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
      needs :commits, :start_date, :end_date, :status, :locales

      protected

      def body_content
        article(class: 'container home-container') do
          translation_request_form if current_user.monitor? && Project.count > 0
          filter_form
          commits_table
          pagination_links
        end
      end

      def translation_request_form
        a(href: '#request-translation', class: "show-request-translation-form-link btn btn-success") do
          i class: "icon-plus-sign"
          text " Request New Translation"
        end

        projects = Project.order('LOWER(name) ASC')
        form_for(Commit.new, url: project_commits_path(projects.first, format: 'json'), html: {class: "well form-horizontal request-translation-form"}) do |f|

          div(class: 'control-group') do
            div(class: 'controls') do
              h2 "Request New Translation"
            end
          end

          div(class: 'control-group') do
            label_tag 'new_commit_project_id', Commit.human_attribute_name(:project_id), class: "control-label"
            div(class: 'controls') do
              select_tag 'new_commit_project_id', options_for_select(projects.map { |pr| [pr.name, pr.to_param] }), required: true, class: "input-xxlarge"
            end
          end

          div(class: 'control-group') do
            f.label :revision, class: "control-label"
            div(class: 'controls') do
              f.text_field :revision, required: true, class: "input-xxlarge"
            end
          end

          div(class: 'control-group') do
            f.label :due_date, class: "control-label"
            div(class: 'controls') do
              input type: 'date', name: 'commit[due_date]', id: 'commit_due_date', class: "input-xxlarge"
            end
          end

          div(class: 'control-group') do
            f.label :pull_request_url, class: "control-label"
            div(class: 'controls') do
              f.text_field :pull_request_url, class: "input-xxlarge"
            end
          end

          div(class: 'control-group') do
            f.label :description, class: "control-label"
            div(class: 'controls') do
              f.text_area :description, class: "input-xxlarge", rows: 3
            end
          end

          div(class: 'control-group') do
            div(class: 'controls') do
              f.submit class: 'btn btn-primary'
            end
          end

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
        table(class: 'table commits-table', id: 'commits') do
          thead do
            tr do
              th "project"
              th "requested"
              th "due", class: "due-date"
              th "priority"
              th "description", class: "description"
              th "requester"
              th "pull"
              th "translate"
              th "review"
              th "id"
              th "translate" if current_user.translator?
            end
          end

          tbody do
            @commits.each do |commit|
              row_class = if commit.loading?
                            'commit-loading'
                          elsif commit.ready?
                            'commit-ready'
                          else
                            'commit-translating'
                          end
              tr(class: row_class) do
                td commit.project.name
                td l(commit.created_at, format: :mon_day)
                td(class: "due-date") do
                  if current_user.admin?
                    form_for commit, url: project_commit_url(commit.project, commit, format: 'json') do |f|
                      f.date_select :due_date,
                                    {use_short_month: true,
                                     start_year:      Date.today.year,
                                     end_year:        Date.today.year + 1,
                                     include_blank:   true},
                                    class: 'no-width'
                    end
                  else
                    if commit.due_date
                      date_class = if commit.due_date < 2.days.from_now.to_date
                                     'due-date-very-soon'
                                   elsif commit.due_date < 5.days.from_now.to_date
                                     'due-date-soon'
                                   else
                                     nil
                                   end
                      span l(commit.due_date, format: :mon_day), class: date_class
                    else
                      text '-'
                    end
                  end
                end
                td do
                  if current_user.admin?
                    form_for commit, url: project_commit_url(commit.project, commit, format: 'json') do |f|
                      f.select :priority, t('models.commit.priority').to_a.map(&:reverse).unshift(['-', nil]), {}, class: 'span1'
                    end
                  else
                    if commit.priority
                      span t("models.commit.priority.#{commit.priority}"), class: "commit-priority-#{commit.priority}"
                    else
                      text '-'
                    end
                  end
                end
                td commit.description || '-', class: "description"
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
                td "#{number_with_delimiter commit.translations_new(*@locales)}s (#{number_with_delimiter commit.words_new(*@locales)}w)"
                td "#{number_with_delimiter commit.translations_pending(*@locales)}s (#{number_with_delimiter commit.words_pending(*@locales)}w)"
                td { link_to commit.revision[0, 6], project_commit_url(commit.project, commit) }
                if current_user.translator?
                  if current_user.approved_locales.any?
                    td do
                      current_user.approved_locales.each do |locale|
                        link_to "#{locale.rfc5646} »", locale_project_url(locale, commit.project, commit: commit.revision)
                        br
                      end
                    end
                  else
                    td do
                      input type:         'text',
                            placeholder:  'locale',
                            class:        'locale-field translate-link-locale',
                            id:           "translate-link-locale-#{commit.revision}",
                            'data-target' => "#translate-link-#{commit.revision}"
                      br
                      link_to "translate »", '#',
                              class:         'translate-link disabled',
                              'data-sha'     => commit.revision,
                              'data-project' => commit.project.to_param,
                              id:            "translate-link-#{commit.revision}"
                    end
                  end
                end
              end
            end
          end
        end
      end

      def filter_form
        form_tag({}, id: 'filter', method: 'get') do
          p(class: 'form-inline') do
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
              unless current_user.admin?
                # So, if you're a monitor, the default filter is by your email,
                # which means the checkbox below is checked. If you uncheck that
                # box, the email param disappears ... so it resets to the default
                # email ... which means the box is checked. There would be no way
                # to uncheck the checkbox if it weren't for this hidden field,
                # which sets the unchecked default to an empty string. That way,
                # if the parameter is present but not set, we know the monitor
                # wants to view all commits. Whew!
                hidden_field_tag 'email', ''
              end
              label_tag({}, class: 'checkbox') do
                check_box_tag 'email', current_user.email, params[:email] == current_user.email
                text 'Only commits submitted by me'
              end
              text ' '
            end
          end

          p(class: 'form-inline') do
            text "Display string and word counts for "
            if current_user.approved_locales.any?
              locales = current_user.approved_locales.map { |locale| [locale.name, locale.rfc5646] }
              locales.unshift ['my locales', current_user.approved_locales.map(&:rfc5646).join(',')]
              locales.unshift ['all locales', nil]
              select_tag 'locales', options_for_select(locales, @locales.map(&:rfc5646).join(','))
            else
              text_field_tag 'locales', @locales.map(&:rfc5646).join(','), placeholder: "all locales", class: 'locale-field locale-field-list'
            end
          end

          p { submit_tag 'Filter', class: 'btn btn-primary' }
        end
      end
    end
  end
end
