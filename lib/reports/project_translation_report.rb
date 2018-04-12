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
  module ProjectTranslationReport
    def self.generate_csv(start_date, end_date)
      # verify that the params are dates
      raise ArgumentError, 'start_date is not a date' unless start_date.instance_of?(Date)
      raise ArgumentError, 'end_date is not a date' unless end_date.instance_of?(Date)

      # verify that the end date is after the start dates
      raise ArgumentError, 'end_date cannot be earlier than the start date' if end_date < start_date

      CSV.generate do |csv|
        translations  = Translation.where(translation_date: start_date.beginning_of_day..end_date.end_of_day)
                                   .joins(key: :project)
                                   .group(['projects.name','translations.rfc5646_locale'])
                                   .sum(:words_count)
        languages = translations.keys.map {|k| k[1]}.uniq.sort
        empty_cols = Array.new(languages.count - 1, '')

        csv << ['Start Date', start_date] + empty_cols
        csv << ['End Date', end_date] + empty_cols
        csv << [''] + empty_cols
        csv << ['Project'] + languages

        projects = translations.keys.map(&:first).uniq.sort

        projects.each do |project|
          row = [project]

          languages.each do |language|
            lang_total = translations[[project, language]] || 0
            row += [lang_total]
          end

          csv << row
        end
      end

    end
  end
end
