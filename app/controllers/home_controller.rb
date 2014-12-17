# Copyright 2014 Square Inc.
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
  # | `articles_filter__project_id`       | A Project ID to filter Articles by (default all Projects).                                                            |
  # | `articles_filter__name`             | A name to filter Articles by.                                                                                         |

  def index
    @form = HomeIndexForm.new(params, cookies)
    items_finder = HomeIndexItemsFinder.new(current_user, @form)
    @commits = items_finder.find_commits
    @articles = items_finder.find_articles
    @presenter = HomeIndexPresenter.new(@commits, @articles, @form[:filter__locales])
  end
end
