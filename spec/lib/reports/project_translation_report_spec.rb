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

require 'spec_helper'

describe Reports::ProjectTranslationReport do
  describe '#generate_csv' do
    it 'throws an exception if start_date is nil' do
      expect { Reports::ProjectTranslationReport.generate_csv(nil, Date.today) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if end_date is nil' do
      expect { Reports::ProjectTranslationReport.generate_csv(Date.today, nil) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if end_date is before start_date' do
      start_date = Date.today
      end_date = start_date.prev_year

      expect { Reports::ProjectTranslationReport.generate_csv(start_date, end_date) }.to raise_error(ArgumentError)
    end

    describe 'CSV Data' do
      before :context do
        @start_date = Date.today
        @end_date = @start_date.next_month
        translation_date = @start_date.next_day

        project = FactoryGirl.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        key1 = FactoryGirl.create(:key, project: project)
        key2 = FactoryGirl.create(:key, project: project)
        key3 = FactoryGirl.create(:key, project: project)

        FactoryGirl.create(:translation, key: key1, rfc5646_locale: 'fr', translation_date: translation_date)
        FactoryGirl.create(:translation, key: key2, rfc5646_locale: 'it', translation_date: translation_date)
        FactoryGirl.create(:translation, key: key3, rfc5646_locale: 'it', translation_date: translation_date)

        csv = Reports::ProjectTranslationReport.generate_csv(@start_date, @end_date)
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
        expected_results = ["Project", "source", "fr", "it"]

        expect(@result[3]).to eql expected_results
      end

      it 'has the expected data for the timeframe' do
        expected_results = ['Foo', '3', '1', '2']

        expect(@result[4]).to eql expected_results
      end
    end

  end
end
