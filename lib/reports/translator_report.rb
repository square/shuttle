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
                                      .includes(:reviewer, :translator, key: :project)

        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << ['Language(s)', "#{languages.sort.join(", ").upcase}"] + empty_cols
        csv << ['', ''] + empty_cols
        csv << ['Translator Report', ''] + empty_cols
        csv << ['Date', 'Translator', 'Language', 'Project Name', 'Reviewed', 'Words Translated', 'New Words (0-69%)', '70-79', '80-89', '90-99', '100%']

        dates = translator_query.map {|t| (t.translation_date || t.review_date).to_date }.uniq.sort

        dates.each do |date|
          # retrieve the translations/reviews for the given date
          date_translations = translator_query.select{|t| t.translation_date&.to_date == date || t.review_date&.to_date == date }

          projects = date_translations.map{|t| t.key.project}.uniq.sort
          projects.each do |project|
            project_translations = date_translations.select{|t| t.key.project == project}

            languages = project_translations.map(&:rfc5646_locale).uniq.sort
            languages.each do |language|
              # for each date, get the users who have made modifications to the translations, note the user may be nil here, thus the use of compact
              users = project_translations.flat_map{|t| [t.reviewer, t.translator]}.uniq.compact.sort

              if exclude_internal
                internal_domains = Shuttle::Configuration.reports.internal_domains
                users.reject!{|u| u.email.end_with?(*internal_domains)}
              end
              users.each do |user|
                language_translations = project_translations.select{|t| t.rfc5646_locale == language}

                reviewed_words = language_translations.select{|t| t.reviewer == user}.sum(&:words_count)
                translated_words = language_translations.select{|t| t.translator == user}.sum(&:words_count)

                # Now pair down the list where the user is either the translator or reviewer
                user_translations = language_translations.select{|t| t.reviewer == user || t.translator == user }

                total_lt_70 = user_translations.select {|t| t.tm_match >= 0  && t.tm_match <= 69.99 }.sum(&:words_count)
                total_70    = user_translations.select {|t| t.tm_match >= 70 && t.tm_match <= 79.99 }.sum(&:words_count)
                total_80    = user_translations.select {|t| t.tm_match >= 80 && t.tm_match <= 89.99 }.sum(&:words_count)
                total_90    = user_translations.select {|t| t.tm_match >= 90 && t.tm_match <= 99.99 }.sum(&:words_count)
                total_100   = user_translations.select {|t| t.tm_match == 100.0 }.sum(&:words_count)

                csv << [date, user.first_name, language.upcase, project.name,
                        reviewed_words, translated_words, total_lt_70,
                        total_70, total_80, total_90, total_100]
              end
            end
          end
        end
      end
    end
  end
end
