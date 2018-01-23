# Copyright 2018 Square Inc.
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

require 'rails_helper'

RSpec.describe Reports::BacklogReport do
  describe '#generate_csv' do
    it 'throws an exception if start_date is nil' do
      expect { Reports::BacklogReport.generate_csv(nil, Date.today) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if end_date is nil' do
      expect { Reports::BacklogReport.generate_csv(Date.today, nil) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if end_date is before start_date' do
      start_date = Date.today
      end_date = start_date.prev_year

      expect { Reports::BacklogReport.generate_csv(start_date, end_date) }.to raise_error(ArgumentError)
    end

    describe 'CSV Data' do
      before :context do
        @start_date = Date.today
        @end_date = @start_date.next_month
        @created_at = @start_date.next_day
        @translation_date = @created_at + 2

        project = FactoryBot.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        key1 = FactoryBot.create(:key, project: project)
        key2 = FactoryBot.create(:key, project: project)
        key3 = FactoryBot.create(:key, project: project)

        FactoryBot.create(:translation, key: key1, translation_date: @translation_date, source_copy: 'This is a test', rfc5646_locale: 'fr', created_at: @created_at)
        FactoryBot.create(:translation, key: key2, translation_date: @translation_date, source_copy: 'Another test', rfc5646_locale: 'it', created_at: @created_at)
        FactoryBot.create(:translation, key: key3, translation_date: nil, source_copy: 'Final test',rfc5646_locale: 'it', created_at: @created_at)

        csv = Reports::BacklogReport.generate_csv(@start_date, @end_date)
        @result = CSV.parse(csv)
      end

      it 'has the expected start and end date' do
        expected_results = [
          ["Start Date", @start_date.strftime("%Y-%m-%d"), "", ""],
          ["End Date", @end_date.strftime("%Y-%m-%d"), "", ""]
        ]

        expect(@result[0..1]).to eql expected_results
      end

      it 'has the row headers' do
        expected_results = ["Date", "", "fr (total words)", "it (total words)"]

        expect(@result[4]).to eql expected_results
      end

      it 'has has the correct data (row 4, day 1)' do
        expected_results = [@created_at.strftime("%Y-%m-%d"), "", "4", "4"]

        expect(@result[5]).to eql expected_results
      end

      it 'has has the correct data (row 5, day 2)' do
        expected_results = [(@created_at + 1).strftime("%Y-%m-%d"), "", "4", "4"]

        expect(@result[6]).to eql expected_results
      end

      it 'has has the correct data (row 6, day 3, translation day)' do
        expected_results = [(@created_at + 2).strftime("%Y-%m-%d"), "", "0", "2"]

        expect(@result[7]).to eql expected_results
      end

      it 'has has the correct data (row 7, day 4, day after translation)' do
        expected_results = [(@created_at + 3).strftime("%Y-%m-%d"), "", "0", "2"]

        expect(@result[8]).to eql expected_results
        # these results are the same for every day after day 4 (day 4 - end_date)
      end
    end
  end
end
