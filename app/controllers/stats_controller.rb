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

  # Displays the statistics page.
  def index
    metrics_offset_in_days = (params[:metrics_offset_in_days] || 30).to_i
    metrics = DailyMetric.
      where(date: (metrics_offset_in_days.days.ago)...Date.today).
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
    @num_words_completed_per_language = decorate_num_words_completed_per_language(this_week_metrics)

    @num_commits_loaded_this_week = this_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_loaded }
    @num_commits_completed_this_week = this_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_completed }

    @num_commits_loaded_last_week = last_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_loaded }
    @num_commits_completed_last_week = last_week_metrics.
      reduce(0) { |total, m| total + m.num_commits_completed }

    respond_to do |format|
      format.html
      format.csv { render text: generate_commit_csv }
    end
  end

  def translation_report
  end

  def generate_translation_report
    begin
      start_date =  Date.strptime(params[:start_date], '%m/%d/%Y')
      end_date =  Date.strptime(params[:end_date], '%m/%d/%Y')
      filename = "translation-word-report-#{start_date.strftime('%Y-%m-%d')}-to-#{end_date.strftime('%Y-%m-%d')}.csv"
      send_data Reports::TranslationWordReport.generate_csv(start_date, end_date), filename: filename
    rescue
      render text: t('controllers.stats.reports.failure'), status: 400
    end
  end

  def project_translation_report
  end

  def generate_project_translation_report
    begin
      start_date =  Date.strptime(params[:start_date], '%m/%d/%Y')
      end_date =  Date.strptime(params[:end_date], '%m/%d/%Y')
      filename = "project-translation-report-#{start_date.strftime('%Y-%m-%d')}-to-#{end_date.strftime('%Y-%m-%d')}.csv"
      send_data Reports::ProjectTranslationReport.generate_csv(start_date, end_date), filename: filename
    rescue
      render text: t('controllers.stats.reports.failure'), status: 400
    end
  end

  def incoming_new_words_report
  end

  def generate_incoming_new_words_report
    begin
      start_date =  Date.strptime(params[:start_date], '%m/%d/%Y')
      end_date =  Date.strptime(params[:end_date], '%m/%d/%Y')
      filename = "incoming-new-words-report-#{start_date.strftime('%Y-%m-%d')}-to-#{end_date.strftime('%Y-%m-%d')}.csv"
      send_data Reports::IncomingNewWordsReport.generate_csv(start_date, end_date), filename: filename
    rescue
      render text: t('controllers.stats.reports.failure'), status: 400
    end
  end

  def translator_report
    @languages = Project.pluck(:targeted_rfc5646_locales, :base_rfc5646_locale).map { |hash, base| hash.keys - [base]}.flatten.uniq.sort
  end

  def generate_translator_report
    begin
      start_date =  Date.strptime(params[:start_date], '%m/%d/%Y')
      end_date =  Date.strptime(params[:end_date], '%m/%d/%Y')
      languages = params[:languages]
      exclude_internal = (params[:exclude_internal] || false)

      filename = "translator-report-#{start_date.strftime('%Y-%m-%d')}-to-#{end_date.strftime('%Y-%m-%d')}.csv"
      send_data Reports::TranslatorReport.generate_csv(start_date, end_date, languages, exclude_internal), filename: filename
    rescue
      render text: t('controllers.stats.reports.failure'), status: 400
    end
  end

  def backlog_report
  end

  def generate_backlog_report
    begin
      start_date =  Date.strptime(params[:start_date], '%m/%d/%Y')
      end_date =  Date.strptime(params[:end_date], '%m/%d/%Y')
      filename = "backlog-report-#{start_date.strftime('%Y-%m-%d')}-to-#{end_date.strftime('%Y-%m-%d')}.csv"
      send_data Reports::BacklogReport.generate_csv(start_date, end_date), filename: filename
    rescue
      render text: t('stats.reports.failure'), status: 400
    end
  end

  private

  def generate_commit_csv
    CSV.generate do |csv|
      csv << ['Date Created', 'Time Created', 'SHA', 'Project', 'Loading Time']
      Commit.where(loading: false).each do |commit|
        if commit.loaded_at && commit.created_at
          date_created = commit.created_at.strftime("%m-%d-%Y")
          time_created = commit.created_at.strftime("%H:%M:%S %Z")
          sha = commit.revision
          project = commit.project.name
          seconds_to_complete = (commit.loaded_at - commit.created_at)
          load_time = Time.at(seconds_to_complete).utc.strftime("%H:%M:%S")
          csv << [date_created, time_created, sha, project, load_time]
        end
      end
    end
  end

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
    # Convert to [Timestamp, Load Time (in minutes)]
    metrics.map { |m| {x: m.date.to_time.to_i * 1000, y: m.avg_load_time / 60} }
  end

  def decorate_num_commits_loaded(metrics)
    metrics.map { |m| {x: m.date.to_time.to_i * 1000, y: m.num_commits_loaded} }
  end
end
