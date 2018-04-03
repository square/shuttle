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

      empty_cols = Array.new(9, '')

      CSV.generate do |csv|
        date_query = Translation.unscoped.where(
                      translation_date: start_date.beginning_of_day..end_date.end_of_day,
                      review_date:      start_date.beginning_of_day..end_date.end_of_day)

        translator_query = Translation.where(date_query.where_values.inject(:or))
                                      .where('tm_match IS NOT NULL')
                                      .where(rfc5646_locale: languages)
                                      .joins(key: :project)
                                      .joins('LEFT OUTER JOIN "users" as u ON u.id = translator_id')
                                      .joins('LEFT OUTER JOIN "users" as u2 ON u2.id = reviewer_id')
                                      .select('RANK() OVER (
                                         ORDER BY DATE(translation_date), rfc5646_locale, name, u.first_name
                                      ) AS group_id,
                                      DATE(translation_date) as translation_date,
                                      DATE(review_date) as review_date,
                                      rfc5646_locale,
                                      projects.name,
                                      u.first_name as translator_name,
                                      u2.first_name as reviewer_name,
                                      u.email as translator_email,
                                      u2.email as reviewer_email,
                                      CASE
                                        WHEN tm_match < 60 THEN 59
                                        WHEN tm_match >= 60 AND tm_match < 70 THEN 60
                                        WHEN tm_match >= 70 AND tm_match < 80 THEN 70
                                        WHEN tm_match >= 80 AND tm_match < 90 THEN 80
                                        WHEN tm_match >= 90 AND tm_match < 100 THEN 90
                                        WHEN tm_match = 100 THEN 100
                                      END AS classification,
                                      SUM(words_count) as words_count')
                                      .group('DATE(translation_date), rfc5646_locale, DATE(review_date), name, u.first_name, u2.first_name, u.email, u2.email, classification')
                                      .order('group_id', :rfc5646_locale, 'projects.name', 'u.first_name')
        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << ['Language(s)', "#{languages.sort.join(", ").upcase}"] + empty_cols
        csv << ['', ''] + empty_cols
        csv << ['Translator Report', ''] + empty_cols
        csv << ['Date', 'Translator', 'Language', 'Project Name', 'Reviewed', 'Words Translated', 'New Words (0-59%)', '60-69', '70-79', '80-89', '90-99', '100%']

        grid = PivotTable::Grid.new do |g|
          g.source_data  = translator_query
          g.column_name  = 'classification'
          g.row_name     = 'group_id'
          g.value_name   = 'words_count'
        end

        grid.build

        grid.rows.each do |row|
          tran = row.data.find{|x| !x.nil?}
          users = ([{name: tran.translator_name, email: tran.translator_email}] + [{name: tran.reviewer_name, email: tran.reviewer_email}]).reject { |h| h[:email].nil? }.uniq.sort_by{ |h| h[:name] }

          if exclude_internal
            internal_domains = Shuttle::Configuration.reports.internal_domains
            users.reject!{|u| u[:email].end_with?(*internal_domains)}
          end

          users.each do |user|
            date = (tran.translation_date || tran.review_date)

            date_translations = translator_query.select{|t| t.translation_date == date || t.review_date == date }
            language_translations = date_translations.select{|t| t.rfc5646_locale == tran.rfc5646_locale }
            reviewed_words = language_translations.select{|t| t.reviewer_email == user[:email] && t.name == tran[:name] }.sum(&:words_count)
            translated_words = language_translations.select{|t| t.translator_email == user[:email] && t.name == tran[:name] }.sum(&:words_count)

            next if reviewed_words == 0 && translated_words == 0

            data = [date.utc.strftime('%Y-%m-%d'), user[:name], tran.rfc5646_locale.upcase, tran[:name], reviewed_words, translated_words]
            %w{59 60 70 80 90 100}.each do |classification|
              value = row.column_data(classification) || 0
              if value.instance_of? Translation
                data << value.words_count
              else
                data << value
              end
            end

            csv << data
          end
        end
      end
    end
  end
end
