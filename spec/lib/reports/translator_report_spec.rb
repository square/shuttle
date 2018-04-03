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

require 'rails_helper'

RSpec.describe Reports::TranslatorReport do
  describe '#generate_csv' do
    it 'throws an exception if start_date is nil' do
      expect { Reports::TranslatorReport.generate_csv(nil, Date.today, ['fr']) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if end_date is nil' do
      expect { Reports::TranslatorReport.generate_csv(Date.today, nil, ['fr']) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if end_date is before start_date' do
      start_date = Date.today
      end_date = start_date.prev_year

      expect { Reports::TranslatorReport.generate_csv(start_date, end_date, ['fr']) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if the languages are nil or empty' do
      start_date = Date.today
      end_date = start_date.next_day

      expect { Reports::TranslatorReport.generate_csv(start_date, end_date, nil) }.to raise_error(ArgumentError)
      expect { Reports::TranslatorReport.generate_csv(start_date, end_date, []) }.to raise_error(ArgumentError)
    end

    it 'throws an exception if the languages are not an array' do
      start_date = Date.today
      end_date = start_date.next_day

      expect { Reports::TranslatorReport.generate_csv(start_date, end_date, 'fr') }.to raise_error(ArgumentError)
    end

    describe 'CSV Data' do
      before :context do
        @start_date = Date.today
        @end_date = @start_date.next_day
        @languages = ['it', 'fr']

        project = FactoryBot.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        reviewer = FactoryBot.create(:user, :reviewer, approved_rfc5646_locales: %w(it fr), first_name: 'Mark')
        translator = FactoryBot.create(:user, :translator, approved_rfc5646_locales: %w(it fr), first_name: 'Rebecca')

        key1 = FactoryBot.create(:key, project: project)
        key2 = FactoryBot.create(:key, project: project)
        key3 = FactoryBot.create(:key, project: project)
        key4 = FactoryBot.create(:key, project: project)

        FactoryBot.create(:translation, key: key1, rfc5646_locale: 'fr', tm_match: 71, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key2, rfc5646_locale: 'it', tm_match: 85, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key3, rfc5646_locale: 'it', tm_match: 60, source_copy: 'One two three', translation_date: @end_date, review_date: nil, reviewer: nil, translator: reviewer)
        FactoryBot.create(:translation, key: key4, rfc5646_locale: 'it', tm_match: 90, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: translator, translator: translator)

        csv = Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages)
        @result = CSV.parse(csv)
      end

      it 'has the expected start and end date' do
        expected_results = [
          ["Start Date", @start_date.strftime("%Y-%m-%d"), "", "", "", "", "", "", "", "", ""],
          ["End Date", @end_date.strftime("%Y-%m-%d"), "", "", "", "", "", "", "", "", ""]
        ]
        expect(@result[0..1]).to eql expected_results
      end

      it 'has the expected languages' do
        expected_results = ["Language(s)", "FR, IT", "", "", "", "", "", "", "", "", ""]
        expect(@result[2]).to eql expected_results
      end

      context 'data for timeframe' do
        it 'has the expected row 6' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    'FR', 'Foo', '3', '0', '0', '0', '3', '0', '0', '0']
          expect(@result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'FR', 'Foo', '0', '3', '0', '0', '3', '0', '0', '0']
          expect(@result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    'IT', 'Foo', '3', '0', '0', '0', '0', '3', '0', '0']
          expect(@result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'IT', 'Foo', '0', '3', '0', '0', '0', '3', '0', '0']
          expect(@result[9]).to eql expected_results
        end

        it 'has the expected row 10' do
          expected_results = [@end_date.strftime("%Y-%m-%d"),  'Mark',  'IT', 'Foo', '0', '3', '0', '3', '0', '0', '0', '0']
          expect(@result[10]).to eql expected_results
        end

        it 'has the expected row 11' do
          expected_results = [@end_date.strftime("%Y-%m-%d"),  'Rebecca',  'IT', 'Foo', '3', '3', '0', '0', '0', '0', '3', '0']
          expect(@result[11]).to eql expected_results
        end

        it 'has the expected row 12' do
          expect(@result[12]).to eql nil
        end
      end
    end
    describe 'Internal Users' do
      before :context do
        @start_date = Date.today
        @end_date = @start_date.next_day
        @languages = ['it', 'fr']
        exclude_internal = true

        project = FactoryBot.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        reviewer = FactoryBot.create(:user, :reviewer, approved_rfc5646_locales: %w(it fr), first_name: 'Chase', email: 'chase@test.host')
        translator = FactoryBot.create(:user, :translator, approved_rfc5646_locales: %w(it fr), first_name: 'Rebecca')

        key1 = FactoryBot.create(:key, project: project)
        key2 = FactoryBot.create(:key, project: project)
        key3 = FactoryBot.create(:key, project: project)
        key4 = FactoryBot.create(:key, project: project)

        FactoryBot.create(:translation, key: key1, rfc5646_locale: 'fr', tm_match: 71, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key2, rfc5646_locale: 'it', tm_match: 85, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key3, rfc5646_locale: 'it', tm_match: 60, source_copy: 'One two three', translation_date: @end_date, review_date: nil, reviewer: nil, translator: @reviewer)
        FactoryBot.create(:translation, key: key4, rfc5646_locale: 'it', tm_match: 90, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: translator, translator: translator)

        csv = Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages, exclude_internal)
        @result = CSV.parse(csv)
      end

      context 'excludes internal users with an internal email address' do
        it 'has the expected row 6' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'FR', 'Foo', '0', '3', '0', '0', '3', '0', '0', '0']
          expect(@result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'IT', 'Foo', '0', '3', '0', '0', '0', '3', '0', '0']
          expect(@result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@end_date.strftime("%Y-%m-%d"),  'Rebecca',  'IT', 'Foo', '3', '3', '0', '0', '0', '0', '3', '0']
          expect(@result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expect(@result[9]).to eql nil
        end
      end
    end
    describe 'Multiple Projects' do
      before :context do
        @start_date = Date.today
        @end_date = @start_date.next_day
        @languages = ['it', 'fr']
        exclude_internal = true

        project = FactoryBot.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        project2 = FactoryBot.create(:project, name: 'Bar', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        reviewer = FactoryBot.create(:user, :reviewer, approved_rfc5646_locales: %w(it fr), first_name: 'Mark')
        translator = FactoryBot.create(:user, :translator, approved_rfc5646_locales: %w(it fr), first_name: 'Rebecca')

        key1 = FactoryBot.create(:key, project: project)
        key2 = FactoryBot.create(:key, project: project)
        key3 = FactoryBot.create(:key, project: project2)
        key4 = FactoryBot.create(:key, project: project2)

        FactoryBot.create(:translation, key: key1, rfc5646_locale: 'fr', tm_match: 71, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key2, rfc5646_locale: 'it', tm_match: 85, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key3, rfc5646_locale: 'it', tm_match: 60, source_copy: 'One two three', translation_date: @end_date, review_date: nil, reviewer: nil, translator: @reviewer)
        FactoryBot.create(:translation, key: key4, rfc5646_locale: 'it', tm_match: 90, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: translator, translator: translator)

        csv = Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages, exclude_internal)
        @result = CSV.parse(csv)
      end

      context 'has the expected project breakdown' do
        it 'has the expected row 6' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    'FR', 'Foo', '3', '0', '0', '0', '3', '0', '0', '0']
          expect(@result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'FR', 'Foo', '0', '3', '0', '0', '3', '0', '0', '0']
          expect(@result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    'IT', 'Foo', '3', '0', '0', '0', '0', '3', '0', '0']
          expect(@result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'IT', 'Foo', '0', '3', '0', '0', '0', '3', '0', '0']
          expect(@result[9]).to eql expected_results
        end

        it 'has the expected row 10' do
          expected_results = [@end_date.strftime("%Y-%m-%d"),  'Rebecca',  'IT', 'Bar', '3', '3', '0', '0', '0', '0', '3', '0']
          expect(@result[10]).to eql expected_results
        end

        it 'has the expected row 11' do
          expect(@result[11]).to eql nil
        end
      end
    end
    describe 'Language Filter' do
      before :context do
        @start_date = Date.today
        @end_date = @start_date.next_day
        @languages = ['fr']
        exclude_internal = true

        project = FactoryBot.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        reviewer = FactoryBot.create(:user, :reviewer, approved_rfc5646_locales: %w(it fr), first_name: 'Mark')
        translator = FactoryBot.create(:user, :translator, approved_rfc5646_locales: %w(it fr), first_name: 'Rebecca')

        key1 = FactoryBot.create(:key, project: project)
        key2 = FactoryBot.create(:key, project: project)
        key3 = FactoryBot.create(:key, project: project)
        key4 = FactoryBot.create(:key, project: project)

        FactoryBot.create(:translation, key: key1, rfc5646_locale: 'fr', tm_match: 71, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key2, rfc5646_locale: 'it', tm_match: 85, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: reviewer, translator: translator)
        FactoryBot.create(:translation, key: key3, rfc5646_locale: 'it', tm_match: 60, source_copy: 'One two three', translation_date: @end_date, review_date: nil, reviewer: nil, translator: @reviewer)
        FactoryBot.create(:translation, key: key4, rfc5646_locale: 'it', tm_match: 90, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: translator, translator: translator)

        csv = Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages, exclude_internal)
        @result = CSV.parse(csv)
      end

      context 'has the expected project breakdown' do
        it 'has the expected row 6' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    'FR', 'Foo', '3', '0', '0', '0', '3', '0', '0', '0']
          expect(@result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', 'FR', 'Foo', '0', '3', '0', '0', '3', '0', '0', '0']
          expect(@result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expect(@result[8]).to eql nil
        end
      end
    end
  end
end
