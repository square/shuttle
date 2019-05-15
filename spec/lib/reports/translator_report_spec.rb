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
      before do
        @start_date = Date.today
        @end_date = @start_date.next_month
        @languages = ['it', 'fr']

        @project = FactoryBot.create(:project, name: 'Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true })
        @article_project = FactoryBot.create(:project, name: 'Article Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true }, job_type: 1)
        @asset_project = FactoryBot.create(:project, name: 'Asset Foo', targeted_rfc5646_locales: { 'en-US' => true, 'fr' => true, 'it' => true }, job_type: 2)
        @commit = FactoryBot.create(:commit, project: @project, approved_at: @end_date)
        @reviewer = FactoryBot.create(:user, :reviewer, approved_rfc5646_locales: %w(it fr), first_name: 'Mark', email: 'mark@test.host')
        @translator = FactoryBot.create(:user, :translator, approved_rfc5646_locales: %w(it fr), first_name: 'Rebecca')
        @article = FactoryBot.create(:article, project: @article_project, created_at: @start_date, last_completed_at: @end_date)
        @asset = FactoryBot.create(:asset, project: @asset_project, created_at: @start_date, approved_at: @end_date)

        key1 = FactoryBot.create(:key, project: @project)
        key2 = FactoryBot.create(:key, project: @project)
        key3 = FactoryBot.create(:key, project: @project)
        key4 = FactoryBot.create(:key, project: @project)
        key5 = FactoryBot.create(:key, project: @article_project)
        key6 = FactoryBot.create(:key, project: @asset_project)
        @commit.keys << [key1, key2, key3, key4]
        @asset.keys << [key6]

        t1 = FactoryBot.create(:translation, key: key1, rfc5646_locale: 'fr', tm_match: 71, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: @reviewer, translator: @translator)
        FactoryBot.create(:translation_change, translation: t1, project: @project, sha: @commit.revision, is_edit: false, user: @translator, role: 'translator', created_at: @start_date, tm_match: t1.tm_match)
        FactoryBot.create(:translation_change, translation: t1, project: @project, sha: @commit.revision, is_edit: true, user: @reviewer, role: 'reviewer', created_at: @start_date, tm_match: t1.tm_match)
        FactoryBot.create(:translation_change, translation: t1, project: @project, sha: @commit.revision, is_edit: true, user: @reviewer, role: 'reviewer', created_at: @start_date + 1.day, tm_match: t1.tm_match)

        t2 = FactoryBot.create(:translation, key: key2, rfc5646_locale: 'it', tm_match: 85, source_copy: 'One two three', translation_date: @start_date, review_date: @start_date, reviewer: @reviewer, translator: @translator)
        FactoryBot.create(:translation_change, translation: t2, project: @project, sha: @commit.revision, is_edit: false, user: @translator, role: 'translator', created_at: @start_date, tm_match: t2.tm_match)
        FactoryBot.create(:translation_change, translation: t2, project: @project, sha: @commit.revision, is_edit: true, user: @reviewer, role: 'reviewer', created_at: @start_date, tm_match: t2.tm_match)

        t3 = FactoryBot.create(:translation, key: key3, rfc5646_locale: 'it', tm_match: 50, source_copy: 'One two three', translation_date: @end_date, review_date: nil, reviewer: nil, translator: @translator)
        FactoryBot.create(:translation_change, translation: t3, project: @project, sha: @commit.revision, is_edit: false, user: @translator, role: 'translator', created_at: @end_date, tm_match: t3.tm_match)

        t4 = FactoryBot.create(:translation, key: key4, rfc5646_locale: 'it', tm_match: 90, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: @reviewer, translator: @translator)
        FactoryBot.create(:translation_change, translation: t4, project: @project, sha: @commit.revision, is_edit: false, user: @translator, role: 'translator', created_at: @end_date, tm_match: t4.tm_match)
        FactoryBot.create(:translation_change, translation: t4, project: @project, sha: @commit.revision, is_edit: true, user: @reviewer, role: 'reviewer', created_at: @end_date, tm_match: t4.tm_match)

        t5 = FactoryBot.create(:translation, key: key5, rfc5646_locale: 'it', tm_match: 60, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: @reviewer, translator: @translator)
        FactoryBot.create(:translation_change, translation: t5, project: @article_project, sha: nil, article: @article, is_edit: false, user: @translator, role: 'translator', created_at: @end_date, tm_match: t5.tm_match)
        FactoryBot.create(:translation_change, translation: t5, project: @article_project, sha: nil, article: @article, is_edit: true, user: @reviewer, role: 'reviewer', created_at: @end_date, tm_match: t5.tm_match)

        t6 = FactoryBot.create(:translation, key: key6, rfc5646_locale: 'it', tm_match: 70, source_copy: 'One two three', translation_date: @end_date, review_date: @end_date, reviewer: @reviewer, translator: @translator)
        FactoryBot.create(:translation_change, translation: t6, project: @asset_project, sha: nil, asset: @asset, is_edit: false, user: @translator, role: 'translator', created_at: @end_date, tm_match: t6.tm_match)
        FactoryBot.create(:translation_change, translation: t6, project: @asset_project, sha: nil, asset: @asset, is_edit: true, user: @reviewer, role: 'reviewer', created_at: @end_date, tm_match: t6.tm_match)
      end

      context 'header info' do
        let!(:result) { CSV.parse(Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages)) }

        it 'has the expected start and end date' do
          expected_results = [
            ["Start Date", @start_date.strftime("%Y-%m-%d"), "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""],
            ["End Date", @end_date.strftime("%Y-%m-%d"), "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
          ]
          expect(result[0..1]).to eql expected_results
        end

        it 'has the expected languages' do
          expected_results = ["Language(s)", "FR, IT", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]
          expect(result[2]).to eql expected_results
        end

        it 'has the expected column headers' do
          expected_results = ["Date", "User", "User Id", "Role", "Source Language", "Language (Locale)", "Project Name", "Project Type", "Job Name/Id", "Job Start", "Approval Date", "New Words", "60-69%", "70-79%%", "80-89%", "90-99%", "100%"]
          expect(result[5]).to eql expected_results
        end
      end

      context 'data for timeframe' do
        let!(:article) { @article.name }
        let!(:project) { @project.name }
        let!(:sha) { @commit.revision }
        let!(:asset) { @asset.id.to_s }
        let!(:commit_start) { @commit.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:article_start) { @article.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:approved_at) { @end_date.strftime('%Y-%m-%d %H:%M') }
        let!(:asset_start) { @asset.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:result) { CSV.parse(Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages)) }

        it 'has the expected row 6' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",    'reviewer',  'EN-US', 'FR', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'FR', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",     'reviewer', 'EN-US', 'IT', project, @project.job_type.titlecase, sha, commit_start, approved_at,'0', '0', '0', '3', '0', '0']
          expect(result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'IT', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '0', '3', '0', '0']
          expect(result[9]).to eql expected_results
        end

        it 'has the expected row 10' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",        'reviewer', 'EN-US', 'IT',  @article_project.name, @article_project.job_type.titlecase, article, article_start, approved_at, '0', '3', '0', '0', '0', '0']
          expect(result[10]).to eql expected_results
        end

        it 'has the expected row 11' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",     'translator', 'EN-US', 'IT',   @article_project.name, @article_project.job_type.titlecase, article, article_start, approved_at, '0', '3', '0', '0', '0', '0']
          expect(result[11]).to eql expected_results
        end

        it 'has the expected row 12' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",        'reviewer',   'EN-US', 'IT',   @asset_project.name, @asset_project.job_type.titlecase, asset, asset_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[12]).to eql expected_results
        end

        it 'has the expected row 13' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'IT',   @asset_project.name, @asset_project.job_type.titlecase, asset, asset_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[13]).to eql expected_results
        end

        it 'has the expected row 14' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",        'reviewer',   'EN-US', 'IT',   project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '0', '0', '3', '0']
          expect(result[14]).to eql expected_results
        end

        it 'has the expected row 15' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'IT',   project, @project.job_type.titlecase, sha, commit_start, approved_at, '3', '0', '0', '0', '3', '0']
          expect(result[15]).to eql expected_results
        end

        it 'has the expected row 16' do
          expect(result[16]).to eql nil
        end
      end

      context 'exclude internal users' do
        let!(:article) { @article.name }
        let!(:project) { @project.name }
        let!(:sha) { @commit.revision }
        let!(:asset) { @asset.id.to_s }
        let!(:commit_start) { @commit.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:article_start) { @article.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:approved_at) { @end_date.strftime('%Y-%m-%d %H:%M') }
        let!(:asset_start) { @asset.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:result) { CSV.parse(Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages, true)) }

        it 'has the expected row 6' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'FR', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@start_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '0', '3', '0', '0']
          expect(result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT',   @article_project.name, @article_project.job_type.titlecase, article, article_start, approved_at, '0', '3', '0', '0', '0', '0']
          expect(result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT',   @asset_project.name, @asset_project.job_type.titlecase, asset, asset_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[9]).to eql expected_results
        end

        it 'has the expected row 10' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT',   project, @project.job_type.titlecase, sha, commit_start, approved_at, '3', '0', '0', '0', '3', '0']
          expect(result[10]).to eql expected_results
        end

        it 'has the expected row 11' do
          expect(result[11]).to eql nil
        end
      end

      context 'completion date version' do
        let!(:article) { @article.name }
        let!(:project) { @project.name }
        let!(:sha) { @commit.revision }
        let!(:asset) { @asset.id.to_s }
        let!(:commit_start) { @commit.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:article_start) { @article.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:approved_at) { @end_date.strftime('%Y-%m-%d %H:%M') }
        let!(:asset_start) { @asset.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:result) { CSV.parse(Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages, false, 'completed')) }

        it 'has the expected row 6' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",    'reviewer',  'EN-US', 'FR', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'FR', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",        'reviewer', 'EN-US', 'IT',  @article_project.name, @article_project.job_type.titlecase, article, article_start, approved_at, '0', '3', '0', '0', '0', '0']
          expect(result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",     'translator', 'EN-US', 'IT',   @article_project.name, @article_project.job_type.titlecase, article, article_start, approved_at, '0', '3', '0', '0', '0', '0']
          expect(result[9]).to eql expected_results
        end

        it 'has the expected row 10' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",        'reviewer',   'EN-US', 'IT',   @asset_project.name, @asset_project.job_type.titlecase, asset, asset_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[10]).to eql expected_results
        end

        it 'has the expected row 11' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'IT', @asset_project.name, @asset_project.job_type.titlecase, asset, asset_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[11]).to eql expected_results
        end

        it 'has the expected row 12' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Mark',    "#{@reviewer.id}",        'reviewer',   'EN-US', 'IT',   project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '0', '3', '3', '0']
          expect(result[12]).to eql expected_results
        end

        it 'has the expected row 13' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'IT', project, @project.job_type.titlecase, sha, commit_start, approved_at, '3', '0', '0', '3', '3', '0']
          expect(result[13]).to eql expected_results
        end

        it 'has the expected row 14' do
          expect(result[14]).to eql nil
        end
      end
      context 'completion date version: exclude internal users' do
        let!(:article) { @article.name }
        let!(:project) { @project.name }
        let!(:sha) { @commit.revision }
        let!(:asset) { @asset.id.to_s }
        let!(:commit_start) { @commit.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:article_start) { @article.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:approved_at) { @end_date.strftime('%Y-%m-%d %H:%M') }
        let!(:asset_start) { @asset.created_at.strftime('%Y-%m-%d %H:%M') }
        let!(:result) { CSV.parse(Reports::TranslatorReport.generate_csv(@start_date, @end_date, @languages, true, 'completed')) }

        it 'has the expected row 6' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}",  'translator', 'EN-US', 'FR', project, @project.job_type.titlecase, sha, commit_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[6]).to eql expected_results
        end

        it 'has the expected row 7' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT',   @article_project.name, @article_project.job_type.titlecase, article, article_start, approved_at, '0', '3', '0', '0', '0', '0']
          expect(result[7]).to eql expected_results
        end

        it 'has the expected row 8' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT', @asset_project.name, @asset_project.job_type.titlecase, asset, asset_start, approved_at, '0', '0', '3', '0', '0', '0']
          expect(result[8]).to eql expected_results
        end

        it 'has the expected row 9' do
          expected_results = [@end_date.strftime("%Y-%m-%d"), 'Rebecca', "#{@translator.id}", 'translator', 'EN-US', 'IT', project, @project.job_type.titlecase, sha, commit_start, approved_at, '3', '0', '0', '3', '3', '0']
          expect(result[9]).to eql expected_results
        end

        it 'has the expected row 10' do
          expect(result[10]).to  eql nil
        end
      end
    end
  end
end
