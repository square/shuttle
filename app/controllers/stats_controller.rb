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

# Controller that returns information used to render the statistics page.

class StatsController < ApplicationController
  before_filter :authenticate_user!

  respond_to :json
  respond_to :html, only: :index

  # Displays the statistics page.

  def index
    @top_projects             = Translation.total_words_per_project.map { |t| {name: t[0], id: Project.find_by_name(t[0]).id} }[0..4]
    # Commit stats
    @total_commits            = Commit.total_commits
    @total_commits_incomplete = Commit.total_commits_incomplete
    @total_words              = Translation.total_words
    @total_words_new          = Translation.total_words_new
    @total_words_pending      = Translation.total_words_pending
  end

  # Returns the number of words per project.

  def words_per_project
    respond_with Translation.total_words_per_project
  end

  # Returns the average commit completion time by day.

  def average_completion_time
    respond_with Commit.average_completion_time
  end

  # Returns the daily number of commits created by day.

  def daily_commits_created
    respond_with Commit.daily_commits_created
  end

  # Returns the daily number of commits completed by day.

  def daily_commits_finished
    respond_with Commit.daily_commits_finished
  end

  # Returns {#daily_commits_created} and {#average_completion_time} for a
  # project.

  def avg_completion_and_daily_creates
    respond_with(
        average_completion_time: Commit.average_completion_time(params['project_id']),
        daily_creates:           Commit.daily_commits_created(params['project_id'])
    )
  end
end
