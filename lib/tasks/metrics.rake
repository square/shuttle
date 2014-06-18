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

namespace :metrics do
  desc "Update metrics for the latest date"
  task update: :environment do
    Rails.logger.info "[metrics:update] Updating metrics for #{Date.today}."

    date = (Date.parse(ENV['date']) rescue Date.yesterday).at_beginning_of_day
    date_range = date...(date + 1.day)

    commits_loaded = Commit.includes(:project).where(loaded_at: date_range)
    commits_completed = Commit.includes(:project).where(completed_at: date_range)

    translations_created = Translation.not_base.where(created_at: date_range)
    # Proxy for now.  Will require a "completed at" field for Translation in future
    translations_completed = Translation.not_base.where(updated_at: date_range, approved: true)

    metric = DailyMetric.find_or_initialize_by(date: date)
    metric.num_commits_loaded = commits_loaded.count
    metric.num_commits_loaded_per_project = commits_loaded.
      each_with_object(Hash.new(0)) { |c, hash| hash[c.project.name] += 1 }

    metric.num_commits_completed = commits_completed.count
    metric.num_commits_completed_per_project = commits_completed.
      each_with_object(Hash.new(0)) { |c, hash| hash[c.project.name] += 1 }

    if metric.num_commits_loaded.zero?
      metric.avg_load_time = 0.0
      metric.avg_load_time_per_project = {}
    else
      metric.avg_load_time = commits_loaded.
        inject(0) { |total, c| total += (c.loaded_at - c.created_at) }.
        fdiv(metric.num_commits_loaded)
      metric.avg_load_time_per_project = commits_loaded.
        each_with_object(Hash.new(0.0)) do |c, hash|
          hash[c.project.name] += (c.loaded_at - c.created_at).
            fdiv(metric.num_commits_loaded_per_project[c.project.name])
        end
    end

    metric.num_words_created = translations_created.sum('words_count')
    metric.num_words_created_per_language= translations_created.
      each_with_object(Hash.new(0)) { |t, hash| hash[t.rfc5646_locale] += t.words_count }

    metric.num_words_completed = translations_completed.sum('words_count')
    metric.num_words_completed_per_language = translations_completed.
      each_with_object(Hash.new(0)) { |t, hash| hash[t.rfc5646_locale] += t.words_count }

    metric.save
    Rails.logger.info "[metrics:update] Successfully updated metrics for #{Date.today}"
  end
end
