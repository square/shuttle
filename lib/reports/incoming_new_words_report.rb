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
  module IncomingNewWordsReport
    def self.generate_csv(start_date, end_date)
      # verify that the params are dates
      raise ArgumentError, 'start_date is not a date' unless start_date.instance_of?(Date)
      raise ArgumentError, 'end_date is not a date' unless end_date.instance_of?(Date)

      # verify that the end date is after the start dates
      raise ArgumentError, 'end_date cannot be earlier than the start date' if end_date < start_date

      CSV.generate do |csv|
        translations  = Translation.where(created_at: start_date..end_date)
                                   .where('rfc5646_locale != source_rfc5646_locale')
                                   .where('tm_match IS NOT null')
                                   .select('DATE(created_at) as created_at', :rfc5646_locale, :tm_match, :words_count)

        languages = translations.map(&:rfc5646_locale).uniq.sort
        empty_cols = Array.new(languages.count, '')

        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << ['Incoming Report', ''] + empty_cols
        csv << ['', ''] + empty_cols
        csv << ['Date', 'source (total words)'] + languages.map {|l| "#{l} (new words)"}

        dates = translations.map(&:created_at).uniq.sort

        dates.each do |date|
          row = [date.utc.strftime('%Y-%m-%d')]

          row += [translations.select {|t| t.created_at == date}.sum(&:words_count) || 0]

          languages.each do |language|
            new_words = translations.select{|t| t.tm_match < 70 && t.rfc5646_locale == language && t.created_at == date }

            lang_total = new_words.sum(&:words_count) || 0
            row += [lang_total]
          end

          csv << row
        end
      end
    end
  end
end
