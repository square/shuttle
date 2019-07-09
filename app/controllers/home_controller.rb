# Copyright 2014-2018 Square Inc.
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

# Contains landing pages appropriate for each of the User roles.

require 'csv'
require 'date'

class HomeController < ApplicationController
  # Typical number of commits to show per page.
  PER_PAGE = 15

  # Displays a landing page depending on the current User's role.
  #
  # Routes
  # ------
  #
  # * `GET /`
  #
  # Query Parameters
  # ----------------
  #
  # |                                     |                                                                                                                       |
  # |:------------------------------------|:----------------------------------------------------------------------------------------------------------------------|
  # | `filter__status`                    | The readiness status of Commits and Articles to show: "completed", "uncompleted", or "all" (default depends on role). |
  # | `filter__rfc5646_locales`           | An array of rfc5646 locale values joined by commas into a string. Used to filter Commits and Articles.                |
  # | `sort__field`                       | Field to sort Commits and Articles by: 'due', 'created_at', 'priority'.                                               |
  # | `sort__direction`                   | Direction to sort Commits and Article in: 'asc', 'desc'.                                                              |
  # | `commits_filter__project_id`        | A Project ID to filter Commits by (default all Projects).                                                             |
  # | `commits_filter__sha`               | A SHA to filter Commits by.                                                                                           |
  # | `commits_filter__hide_exported`     | A string flag indicating whether exported Commits should be hidden or not: 'true', 'false'.                           |
  # | `commits_filter__hide_autoimported` | A string flag indicating whether auto imported Commits should be hidden or not: 'true', 'false'.                      |
  # | `commits_filter__show_only_mine`    | A string flag indicating whether only Commits from the current user should be shown: 'true', 'false'.                 |
  # | `commits_filter__hide_duplicates`   | A string flag indicating whether only unique Commits should be shown (by fingerprint): 'true', 'false'.                 |
  # | `articles_filter__project_id`       | A Project ID to filter Articles by (default all Projects).                                                            |
  # | `articles_filter__name`             | A name to filter Articles by.                                                                                         |

  def index
    @form = HomeIndexForm.new(params, cookies)
    items_finder = HomeIndexItemsFinder.new(current_user, @form)
    @commits = items_finder.find_commits
    @articles = items_finder.find_articles
    @groups = items_finder.find_groups
    @assets = items_finder.find_assets
    @presenter = HomeIndexPresenter.new(@commits, @articles, @groups, @assets, @form[:filter__locales])
  end

  def csv
    # manually setting how many rows to download
    params[:limit] = 1000
    @form = HomeIndexForm.new(params, cookies)
    type = params[:type]
    items_finder = HomeIndexItemsFinder.new(current_user, @form)
    @commits = items_finder.find_commits
    @articles = items_finder.find_articles
    @groups = items_finder.find_groups
    @assets = items_finder.find_assets
    @items = items_finder.public_send("find_#{type}s")
    @presenter = HomeIndexPresenter.new(@commits, @articles, @groups, @assets, @form[:filter__locales])
    csv_file = CSV.generate do |csv|
      identifier = type == 'commit' ? 'sha' : 'name'
      if identifier == 'sha'
        csv << ['Project',
                'SHA',
                'Created',
                'Due Date',
                'Priority',
                'New Strings',
                'New Words',
                'Review Strings',
                'Review Words',
                'Translate Link',
                'Requester Email']
        @items.each do |item|
          project = Project.find item.project_id
          display_created_date = "#{item.created_at.month}/#{item.created_at.day}/#{item.created_at.year}"
          unless item.due_date.nil?
            display_due_date = "#{item.due_date.month}/#{item.due_date.day}/#{item.due_date.year}"
          end
          strings_to_translate = @presenter.item_stat(item, :translations, :new)
          strings_to_review = @presenter.item_stat(item, :translations, :pending)
          words_to_translate = @presenter.item_stat(item, :words, :new)
          words_to_review = @presenter.item_stat(item, :words, :pending)
          commit_url = project_commit_url(item.project, item)
          requester_email = item.user.email if item.user
          csv << [project.name,
                  commit_url,
                  display_created_date,
                  display_due_date,
                  item.priority,
                  strings_to_translate,
                  words_to_review,
                  strings_to_review,
                  words_to_translate,
                  project_commit_url(project, item),
                  requester_email]
        end
      else
        csv << ['Project',
                'Name',
                'Created',
                'Due Date',
                'Priority',
                'Groups',
                'Review Strings',
                'Review Words',
                'New Strings',
                'New Words',
                'Translate Link',
                'Requester Email']
        @items.each do |item|
          project = Project.find item.project_id
          display_created_date = "#{item.created_at.month}/#{item.created_at.day}/#{item.created_at.year}"
          unless item.due_date.nil?
            display_due_date = "#{item.due_date.month}/#{item.due_date.day}/#{item.due_date.year}"
          end
          groups = item.groups.count
          strings_to_translate = @presenter.item_stat(item, :translations, :new)
          strings_to_review = @presenter.item_stat(item, :translations, :pending)
          words_to_translate = @presenter.item_stat(item, :words, :new)
          words_to_review = @presenter.item_stat(item, :words, :pending)
          article_link = api_v1_project_article_url(item.project.id, item.name)
          requester_email = item.email
          csv << [project.name,
                  article_link,
                  display_created_date,
                  display_due_date,
                  item.priority,
                  groups,
                  strings_to_translate,
                  words_to_translate,
                  strings_to_review,
                  words_to_review,
                  project_commit_url(project, item),
                  requester_email]
        end
      end
    end
    send_data csv_file, type: 'text/plain',
                        filename: "#{type}s.csv",
                        disposition: 'attachment'
  end
end
