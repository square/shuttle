# Copyright 2017 Square Inc.
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

module Reports
  module TranslatorReport
    def self.generate_csv(start_date, end_date, languages, exclude_internal = false)
      # verify that the params are dates
      raise ArgumentError, 'start_date is not a date' unless start_date.instance_of?(Date)
      raise ArgumentError, 'end_date is not a date' unless end_date.instance_of?(Date)

      # verify that the end date is after the start dates
      raise ArgumentError, 'end_date cannot be earlier than the start date' if end_date < start_date

      # verify there are languages
      raise ArgumentError, 'languages array must be provided' if languages.blank?
      # and that languages is an array
      raise ArgumentError, 'languages must be an array' unless languages.kind_of?(Array)

      empty_cols = Array.new(13, '')
      internal_domains = Shuttle::Configuration.reports.internal_domains.join('|')

      CSV.generate do |csv|
        translator_query = TranslationChange.where('translation_changes.created_at': start_date.beginning_of_day..end_date.end_of_day)
                                      .where('translation_changes.tm_match IS NOT NULL')
                                      .where('translations.rfc5646_locale': languages)
                                      .joins(:project, :user, :translation)
                                      .joins('LEFT OUTER JOIN articles ON articles.id = article_id')
                                      .joins('LEFT OUTER JOIN commits ON commits.revision = sha')
                                      .group('DATE(translation_changes.created_at), rfc5646_locale, translation_changes.role, projects.name, articles.name, first_name, users.id, sha, classification, DATE(articles.created_at)')
                                      .order('group_id', 'rfc5646_locale', 'projects.name', 'first_name', 'classification')
                                      .select('RANK() OVER (
                                                 ORDER BY DATE(translation_changes.created_at), rfc5646_locale, projects.name, sha, articles.name, first_name
                                              ) AS group_id,
                                              DATE(translation_changes.created_at) as "date",
                                              users.first_name,
                                              users.id as user_id,
                                              translation_changes.role,
                                              rfc5646_locale,
                                              projects.name as project_name,
                                              sha,
                                              articles.name as article_name,
                                              DATE(articles.created_at) as article_date,
                                              CASE
                                                WHEN translation_changes.tm_match < 60 THEN 0
                                                WHEN translation_changes.tm_match >= 60 AND translation_changes.tm_match < 70 THEN 1
                                                WHEN translation_changes.tm_match >= 70 AND translation_changes.tm_match < 80 THEN 2
                                                WHEN translation_changes.tm_match >= 80 AND translation_changes.tm_match < 90 THEN 3
                                                WHEN translation_changes.tm_match >= 90 AND translation_changes.tm_match < 100 THEN 4
                                                WHEN translation_changes.tm_match = 100 THEN 5
                                              END AS classification,
                                              MAX(commits.created_at) as job_start,
                                              SUM(words_count) as words_count')


        translator_query = translator_query.where("users.email ~ '^(?!.*(#{internal_domains})$).*$'") if exclude_internal

        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << ['Language(s)', "#{languages.sort.join(", ").upcase}"] + empty_cols
        csv << ['', ''] + empty_cols
        csv << ['Translator Report', ''] + empty_cols
        csv << ['Date', 'User', 'User Id', 'Role', 'Language (Locale)', 'Project Name', 'Job Name (SHA)', 'Job Start', 'Article Name', 'Article Date', 'New Words', '60-69%', '70-79%%', '80-89%', '90-99%', '100%']

        translator_query.group_by(&:group_id).each do |group, records|
          tc = records.first

          counts = [0, 0, 0, 0, 0, 0]

          records.each do |rec|
            counts[rec.classification] = rec.words_count
          end
          article = (tc.article_name || '')
          article_date = (tc.article_date ? tc.article_date.strftime('%Y-%m-%d') : '')
          sha = (tc.sha || '')
          job_start = (tc.job_start ? tc.job_start.in_time_zone.strftime('%Y-%m-%d %H:%M %:z') : '')
          csv << [tc.date.strftime('%Y-%m-%d'), tc.first_name, tc.user_id, tc.role, tc.rfc5646_locale.upcase, tc.project_name, sha, job_start, article, article_date, counts].flatten
        end
      end
    end
  end
end
