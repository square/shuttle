module Reports
  module QualityReport
    def self.generate_csv(start_date, end_date, languages, exclude_internal_translators = false, exclude_internal_reviewers = false)
      # verify that the params are dates
      raise ArgumentError, 'start_date is not a date' unless start_date.instance_of?(Date)
      raise ArgumentError, 'end_date is not a date' unless end_date.instance_of?(Date)

      # verify that the end date is after the start dates
      raise ArgumentError, 'end_date cannot be earlier than the start date' if end_date < start_date

      # verify there are languages
      raise ArgumentError, 'languages array must be provided' if languages.blank?
      # and that languages is an array
      raise ArgumentError, 'languages must be an array' unless languages.kind_of?(Array)

      empty_cols = Array.new(11, '')

      query = TranslationChange.where('translation_changes.created_at': start_date.beginning_of_day..end_date.end_of_day)
        .where('translations.review_date IS NOT NULL')
        .joins(:project, :user, translation: :key)
        .joins('LEFT OUTER JOIN edit_reasons ON edit_reasons.translation_change_id = translation_changes.id')
        .joins('LEFT OUTER JOIN reasons ON reasons.id = edit_reasons.reason_id')
        .joins('LEFT OUTER JOIN users as translators ON translators.id = translations.translator_id')
        .joins('LEFT OUTER JOIN users as reviewers ON reviewers.id = translations.reviewer_id')
        .joins('LEFT OUTER JOIN articles ON articles.id = translation_changes.article_id')
        .group('DATE(translation_changes.created_at)')
        .group('projects.name')
        .group('translation_changes.asset_id')
        .group('articles.name')
        .group('translation_changes.sha')
        .group('keys.original_key')
        .group('keys.source_copy')
        .group('translations.rfc5646_locale')
        .group('translations.translator_id')
        .group('translation_changes.diff')
        .group('translations.reviewer_id')
        .group('translations.review_date')
        .group('translators.first_name')
        .group('reviewers.first_name')
        .group('translation_changes.reason_severity')
        .select("DATE(translation_changes.created_at) as date,
              	projects.name,
              	COALESCE(CAST(translation_changes.asset_id as VARCHAR), articles.name, translation_changes.sha) as job_id,
              	keys.original_key as stringkey,
              	keys.source_copy as source_string,
              	UPPER(translations.rfc5646_locale) as language,
              	translators.first_name as translator,
              	translations.translator_id,
              	translation_changes.diff,
              	translations.review_date,
              	reviewers.first_name as reviewer,
              	translations.reviewer_id,
              	ARRAY_TO_STRING(ARRAY_AGG(reasons.name),';') AS reason_string,
              	translation_changes.reason_severity")
        .order('date', 'translations.rfc5646_locale', 'job_id', 'translators.first_name', 'reviewers.first_name')

      internal_domains = Shuttle::Configuration.reports.internal_domains.join('|')
      if exclude_internal_translators
        query = query.where("translators.email ~ '^(?!.*(#{internal_domains})$).*$'")
      end
      if exclude_internal_reviewers
        query = query.where("reviewers.email ~ '^(?!.*(#{internal_domains})$).*$'")
      end

      CSV.generate do |csv|
        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << ['Language(s)', "#{languages.sort.join(", ").upcase}"] + empty_cols
        csv << ['', ''] + empty_cols
        csv << ['Quality Report', ''] + empty_cols
        csv << ['Date Translated  / Reviewed', 'Project',	'Job Name', 'Stringkey', 'Original Source String (EN)',	'Langauge',	'Translator', 'Previous Translated String', 'Date Reviewed', 'Reviewer', 'Updated Translated String', 'Reason(s)',	'Severity (0-3)']

        query.each do |tc|
          csv << [tc.date.strftime('%Y-%m-%d'), tc.name, tc.job_id, tc.stringkey, tc.source_string, tc.language, "#{tc.translator} (#{tc.translator_id})", tc.diff[:copy][0], tc.review_date, "#{tc.reviewer} (#{tc.reviewer_id})", tc.diff[:copy][1], tc.reason_string, tc.reason_severity]
        end
      end
    end
  end
end
