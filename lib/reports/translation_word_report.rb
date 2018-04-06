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
        locales = Project.pluck(:targeted_rfc5646_locales, :base_rfc5646_locale).map { |hash, base| hash.keys - [base]}.flatten.map(&:downcase).uniq.sort
        translation_query = Translation.where(translation_date: start_date.beginning_of_day..end_date.end_of_day)
                                       .select(
                                         'RANK() OVER (
                                           ORDER BY DATE(translation_date), rfc5646_locale
                                          ) AS group_id',
                                          'DATE(translation_date) as translation_date',
                                          :rfc5646_locale,
                                          'CASE
                                            WHEN tm_match < 60 THEN 59
                                            WHEN tm_match >= 60 AND tm_match < 70 THEN 60
                                            WHEN tm_match >= 70 AND tm_match < 80 THEN 70
                                            WHEN tm_match >= 80 AND tm_match < 90 THEN 80
                                            WHEN tm_match >= 90 AND tm_match < 100 THEN 90
                                            WHEN tm_match = 100 THEN 100
                                          END AS classification',
                                          'SUM(words_count) as words_count'
                                       )
                                       .group(['DATE(translation_date)', :rfc5646_locale, 'classification'])

        csv << ['Start Date', start_date, '', '', '', '', '', '', '']
        csv << ['End Date', end_date, '', '', '', '', '', '', '']
        csv << ['Language(s)', "#{locales.join(", ").upcase}", '', '', '', '', '', '', '']
        csv << ['', '', '', '', '', '', '', '', '']
        csv << ['Translated Word Report', '', '', '', '', '', '', '', '']
        csv << ['Date', 'source', 'Target Language', 'New Words (0-59%)', '60-69', '70-79', '80-89', '90-99', '100%']

        grid = PivotTable::Grid.new do |g|
          g.source_data  = translation_query
          g.column_name  = 'classification'
          g.row_name     = 'group_id'
          g.value_name   = 'words_count'
        end

        grid.build
        grid.rows.each do |row|
            tran = row.data.find{|x| !x.nil?}

            data = [tran.translation_date.utc.strftime('%Y-%m-%d'), row.total, tran.rfc5646_locale.upcase]
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
