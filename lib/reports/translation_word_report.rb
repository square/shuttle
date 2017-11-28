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
  module TranslationWordReport
    def self.generate_csv(start_date, end_date)
      # verify that the params are dates
      raise ArgumentError, 'start_date is not a date' unless start_date.instance_of?(Date)
      raise ArgumentError, 'end_date is not a date' unless end_date.instance_of?(Date)

      # verify that the end date is after the start dates
      raise ArgumentError, 'end_date cannot be earlier than the start date' if end_date < start_date

      CSV.generate do |csv|
        locales = Project.pluck(:targeted_rfc5646_locales, :base_rfc5646_locale).map { |hash, base| hash.keys - [base]}.flatten.uniq
        translation_query = Translation
                              .where(translation_date: start_date.beginning_of_day..end_date.end_of_day)
                              .where(rfc5646_locale: locales)

        csv << ['Start Date', start_date, '', '', '', '', '', '', '']
        csv << ['End Date', end_date, '', '', '', '', '', '', '']
        csv << ['Language(s)', "#{locales.join(", ").upcase}", '', '', '', '', '', '', '']
        csv << ['', '', '', '', '', '', '', '', '']
        csv << ['Translated Word Report', '', '', '', '', '', '', '', '']
        csv << ['Date', 'en', 'Target Language', 'New Words (0-59%)', '60-69', '70-79', '80-89', '90-99', '100%']

        start_date.upto(end_date).each do |date|
          translation_for_date = translation_query.select do |t|
            t[:translation_date] >= date.beginning_of_day && t[:translation_date] <= date.end_of_day
          end

          locales.each do |locale|
            translations_for_locale = translation_for_date.select {|t| t[:rfc5646_locale] == locale.downcase }
            total_en = translations_for_locale.count
            next if total_en.zero?

            total_lt_59 = translations_for_locale.select {|t| t[:tm_match] >= 0 && t[:tm_match] <= 59.99 }.count
            total_60 = translations_for_locale.select {|t| t[:tm_match] >= 60 && t[:tm_match] <= 69.99 }.count
            total_70 = translations_for_locale.select {|t| t[:tm_match] >= 70 && t[:tm_match] <= 79.99 }.count
            total_80 = translations_for_locale.select {|t| t[:tm_match] >= 80 && t[:tm_match] <= 89.99 }.count
            total_90 = translations_for_locale.select {|t| t[:tm_match] >= 90 && t[:tm_match] <= 99.99 }.count
            total_100 = translations_for_locale.select {|t| t[:tm_match] == 100.0 }.count

            csv << [date, total_en, locale.upcase, total_lt_59, total_60, total_70, total_80, total_90, total_100]
          end
        end
      end
    end
  end
end
