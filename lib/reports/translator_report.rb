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
    def self.generate_csv(start_date, end_date, languages, exclude_internal = false, report_type = 'standard')
      # verify that the params are dates
      raise ArgumentError, 'start_date is not a date' unless start_date.instance_of?(Date)
      raise ArgumentError, 'end_date is not a date' unless end_date.instance_of?(Date)

      # verify that the end date is after the start dates
      raise ArgumentError, 'end_date cannot be earlier than the start date' if end_date < start_date

      # verify there are languages
      raise ArgumentError, 'languages array must be provided' if languages.blank?
      # and that languages is an array
      raise ArgumentError, 'languages must be an array' unless languages.kind_of?(Array)

      empty_cols = Array.new(15, '')

      CSV.generate do |csv|
        if report_type == 'completed'
          translator_query = get_completion_query(start_date, end_date, languages, exclude_internal)
        else
          translator_query = get_standard_query(start_date, end_date, languages, exclude_internal)
        end

        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << ['Language(s)', "#{languages.sort.join(", ").upcase}"] + empty_cols
        csv << ['', ''] + empty_cols
        csv << ['Translator Report', report_type.titlecase] + empty_cols
        csv << ['Date', 'User', 'User Id', 'Role', 'Source Language', 'Language (Locale)', 'Project Name', 'Project Type', 'Job Name/Id', 'Job Start', 'Approval Date', 'New Words', '60-69%', '70-79%%', '80-89%', '90-99%', '100%']

        translator_query.group_by(&:group_id).each do |group, records|
          tc = records.first

          counts = [0, 0, 0, 0, 0, 0]

          records.each do |rec|
            counts[rec.classification] = rec.words_count
          end
          article = (tc.article_name.blank?) ? nil : tc.article_name
          sha = (tc.sha.blank?) ? nil : tc.sha
          asset = (tc.asset_id.blank?) ? nil : tc.asset_id
          job_start = (tc.job_start ? tc.job_start.in_time_zone.strftime('%Y-%m-%d %H:%M') : '')
          approved_at = (tc.approved_at ? tc.approved_at.in_time_zone.strftime('%Y-%m-%d %H:%M') : '')
          
          csv << [tc.date.strftime('%Y-%m-%d'), tc.first_name, tc.user_id, tc.role, tc.source_rfc5646_locale.upcase, tc.rfc5646_locale.upcase, tc.project_name, Project.job_types.key(tc.job_type).titlecase, (sha || article || asset).to_s, job_start, approved_at, counts].flatten
        end
      end
    end

    def self.add_shared(query, languages, exclude_internal)
      if exclude_internal
        internal_domains = Shuttle::Configuration.reports.internal_domains.join('|')
        query = query.where("users.email ~ '^(?!.*(#{internal_domains})$).*$'")
      end

      query.where('translation_changes.tm_match IS NOT NULL')
           .where('translations.rfc5646_locale': languages)
           .joins(:project, :user, :translation)
           .group('source_rfc5646_locale, rfc5646_locale, translation_changes.role, projects.name, projects.job_type, first_name, users.id, classification')
           .select('users.first_name,
                   users.id as user_id,
                   translation_changes.role,
                   source_rfc5646_locale,
                   rfc5646_locale,
                   projects.name as project_name,
                   projects.job_type as job_type,
                   -- the following take the tm_match and converts it to a number 0-5
                   CASE WHEN translation_changes.tm_match < 60 THEN 0 ELSE FLOOR((translation_changes.tm_match - 50)/10) END as classification,
                   SUM(words_count) as words_count')
    end

    def self.get_standard_query(start_date, end_date, languages, exclude_internal)
      query = TranslationChange.where('translation_changes.created_at': start_date.beginning_of_day..end_date.end_of_day)
        .joins('LEFT OUTER JOIN articles ON articles.id = article_id')
        .joins('LEFT OUTER JOIN commits ON commits.revision = sha')
        .joins('LEFT OUTER JOIN assets ON assets.id = asset_id')
        .group('DATE(translation_changes.created_at)')
        .group('articles.name, sha, assets.id')
        .order('group_id', 'rfc5646_locale', 'source_rfc5646_locale', 'projects.name', 'first_name', 'classification')
        .select('RANK() OVER (
                   ORDER BY DATE(translation_changes.created_at), rfc5646_locale, projects.name, sha, articles.name, assets.id, first_name
                 ) AS group_id,
                 DATE(translation_changes.created_at) as "date",
                 sha,
                 articles.name as article_name,
                 assets.id as asset_id,
                 COALESCE(MIN(commits.created_at), MIN(articles.created_at), MIN(assets.created_at)) as job_start,
                 COALESCE(MAX(commits.approved_at), MAX(articles.last_completed_at), MAX(assets.approved_at)) as approved_at')
      add_shared(query, languages, exclude_internal)
    end

    def self.get_completion_query(start_date, end_date, languages, exclude_internal)
      commit_query = TranslationChange.where('commits.approved_at': start_date.beginning_of_day..end_date.end_of_day)
        .joins('JOIN commits ON commits.revision = sha')
        .group('DATE(commits.approved_at), sha')
        .select('DATE(commits.approved_at) as "date",
                sha,
                NULL as article_name,
                NULL as asset_id,
                MIN(commits.created_at) as job_start,
                MAX(commits.approved_at) as approved_at')
      commit_query = add_shared(commit_query, languages, exclude_internal)

      article_query = TranslationChange.where('articles.last_completed_at': start_date.beginning_of_day..end_date.end_of_day)
        .joins('JOIN articles ON articles.id = article_id')
        .group('DATE(articles.last_completed_at), articles.name')
        .select('DATE(articles.last_completed_at) as "date",
                 NULL,
                 articles.name as article_name,
                 NULL as asset_id,
                 MIN(articles.created_at) as job_start,
                 MAX(articles.last_completed_at) as approved_at')
      article_query = add_shared(article_query, languages, exclude_internal)

      asset_query = TranslationChange.where('assets.approved_at': start_date.beginning_of_day..end_date.end_of_day)
        .joins('JOIN assets ON assets.id = asset_id')
        .group('DATE(assets.approved_at), assets.id')
        .select('DATE(assets.approved_at) as "date",
                NULL as sha,
                NULL as article_name,
                CAST(assets.id as varchar) as asset_id,
                MIN(assets.created_at) as job_start,
                MAX(assets.approved_at) as approved_at')
      asset_query = add_shared(asset_query, languages, exclude_internal)

      TranslationChange.from_cte('foo', commit_query.union(article_query).union(asset_query))
                       .select('RANK() OVER (
                          ORDER BY date, rfc5646_locale, project_name, sha, article_name, asset_id, first_name
                        ) AS group_id, *')
                       .order('group_id', 'rfc5646_locale', 'source_rfc5646_locale', 'project_name', 'first_name', 'classification')
    end


    private_class_method :get_standard_query
    private_class_method :get_completion_query
    private_class_method :add_shared
  end
end
