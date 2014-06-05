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

  respond_to :html

  # Displays the statistics page.
  def index
    metrics = DailyMetric.
      where(date: (30.days.ago)...Date.today).
      order(:date)

    this_week_metrics = DailyMetric.
      where(date: (1.week.ago)...Date.today).
      order(:date)
      
    last_week_metrics = DailyMetric.
      where(date: (2.weeks.ago)...(1.week.ago)).
      order(:date)

    @words_per_project   = decorate_words_per_project(Translation.total_words_per_project)
    @average_load_time   = decorate_avg_load_time(metrics)
    @num_commits_loaded  = decorate_num_commits_loaded(metrics)

    @num_words_created_per_language = decorate_num_words_created_per_language(this_week_metrics)
    @num_words_completed_per_language = decorate_num_words_completed_per_language(last_week_metrics)

    @num_commits_loaded_this_week = this_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_loaded }
    @num_commits_completed_this_week = this_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_completed }

    @num_commits_loaded_last_week = last_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_loaded }
    @num_commits_completed_last_week = last_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_completed }


  end

  private

  def decorate_num_words_created_per_language(metrics)
    metrics.each_with_object({}) do |m, hash|
      hash.merge!(m.num_words_created_per_language) { |k, first, second| first + second }
    end.map { |k, v| {label: k, value: v} }
  end

  def decorate_num_words_completed_per_language(metrics)
    metrics.each_with_object({}) do |m, hash|
      hash.merge!(m.num_words_completed_per_language) { |k, first, second| first + second }
    end.map { |k, v| {label: k, value: v} }
  end

  def decorate_words_per_project(metrics)
    metrics.map { |m| {key: m[0], y: m[1]} }
  end

  def decorate_avg_load_time(metrics)
    # Convert to [Timestamp, Load Time (in hours)]
    metrics.map { |m| {x: m.date.to_time.to_i * 1000, y: m.avg_load_time / 3600} }
  end

  def decorate_num_commits_loaded(metrics)
    metrics.map { |m| {x: m.date.to_time.to_i * 1000, y: m.num_commits_loaded} }
  end
end
