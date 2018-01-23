# Copyright 2014 Square Inc.
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

RSpec.describe StatsController do
  before do
    Translation.delete_all
    user = FactoryBot.create(:user, :activated)
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
  end

  describe "#index" do
    context "format: html" do
      before do
        FactoryBot.create :daily_metric, date: 5.days.ago
        FactoryBot.create :daily_metric, date: 10.days.ago
        FactoryBot.create :translation
        get :index
      end

      it "responds to format: html" do
        expect(response).to be_success
      end

      it "assigns words per project" do
        expect(assigns(:words_per_project).first).to include(:key, y: 19)
      end

      it "assigns average_load_time" do
        expect(assigns(:average_load_time).first).to include(:x, y: 0.05)
      end

      it "assigns num_commits_loaded" do
        expect(assigns(:num_commits_loaded).length).to eql(2)
        expect(assigns(:num_commits_loaded).first).to include(:x, :y)
      end

      it "assigns num_words_created_per_language" do
        expected_num_words_created_per_language = [{:label=>"jp", :value=>30}, {:label=>"fr", :value=>20}]
        expect(assigns(:num_words_created_per_language)).to eql(expected_num_words_created_per_language)
      end

      it "assigns num_words_completed_per_language" do
        expected_num_words_completed_per_language = [{:label=>"jp", :value=>30}, {:label=>"fr", :value=>20}]
        expect(assigns(:num_words_completed_per_language)).to eql([{:label=>"jp", :value=>20}, {:label=>"fr", :value=>10}])
      end

      it "assigns num_commits_loaded_this_week" do
        expect(assigns(:num_commits_loaded_this_week)).to eql(5)
      end

      it "assigns num_commits_completed_this_week" do
        expect(assigns(:num_commits_completed_this_week)).to eql(3)
      end

      it "assigns num_commits_loaded_last_week" do
        expect(assigns(:num_commits_loaded_last_week)).to eql(5)
      end

      it "assigns num_commits_completed_last_week" do
        expect(assigns(:num_commits_completed_last_week)).to eql(3)
      end
    end

    context "format: csv" do
      before do
        loaded_at = Time.utc(2014, 8, 12)
        created_at = loaded_at - 5.minutes
        FactoryBot.create(:commit,
                           loading: false,
                           created_at: created_at,
                           loaded_at: loaded_at)
        FactoryBot.create(:commit, loading: true)
      end

      it "responds to format: csv" do
        get :index, format: :csv
        expect(response).to be_success
      end

      it "contains the proper header columns" do
        get :index, format: :csv
        parsed_header = CSV.parse(response.body)[0]
        expected_header = ["Date Created", "Time Created", "SHA", "Project", "Loading Time"]
        expect(parsed_header).to eql(expected_header)
      end

      it "only contains stats for non-loading commits" do
        get :index, format: :csv
        num_body_rows = CSV.parse(response.body).length - 1
        expect(num_body_rows).to eql(1)
      end

      it "contains the proper stats for the non-loading commit" do
        get :index, format: :csv
        parsed_row = CSV.parse(response.body)[1]
        expect(parsed_row).to include('08-11-2014', '16:55:00 PDT', '00:05:00')
      end
    end
  end

  describe "#generate_translation_report" do
    before do
      @start_date = Date.today
      @end_date = @start_date.next_month
    end

    it 'has a response of 400 if start_date is nil' do
      post :generate_translation_report, format: :csv, start_date: nil, end_date: @end_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'has a response of 400 if if end_date is nil' do
      post :generate_translation_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: nil
      expect(response.status).to eq 400
    end

    it 'throws an exception if end_date is before start_date' do
      post :generate_translation_report, format: :csv, start_date: @end_date.strftime('%m/%d/%Y'), end_date: @start_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'sends a csv file to the client' do
      post :generate_translation_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: @end_date.strftime('%m/%d/%Y')
      expect(response).to be_success
    end
  end

  describe "#generate_project_translation_report" do
    before do
      @start_date = Date.today
      @end_date = @start_date.next_month
    end

    it 'has a response of 400 if start_date is nil' do
      post :generate_project_translation_report, format: :csv, start_date: nil, end_date: @end_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'has a response of 400 if if end_date is nil' do
      post :generate_project_translation_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: nil
      expect(response.status).to eq 400
    end

    it 'throws an exception if end_date is before start_date' do
      post :generate_project_translation_report, format: :csv, start_date: @end_date.strftime('%m/%d/%Y'), end_date: @start_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'sends a csv file to the client' do
      post :generate_project_translation_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: @end_date.strftime('%m/%d/%Y')
      expect(response).to be_success
    end
  end

  describe "#generate_incoming_new_words_report" do
    before do
      @start_date = Date.today
      @end_date = @start_date.next_month
    end

    it 'has a response of 400 if start_date is nil' do
      post :generate_incoming_new_words_report, format: :csv, start_date: nil, end_date: @end_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'has a response of 400 if if end_date is nil' do
      post :generate_incoming_new_words_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: nil
      expect(response.status).to eq 400
    end

    it 'throws an exception if end_date is before start_date' do
      post :generate_incoming_new_words_report, format: :csv, start_date: @end_date.strftime('%m/%d/%Y'), end_date: @start_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'sends a csv file to the client' do
      post :generate_incoming_new_words_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: @end_date.strftime('%m/%d/%Y')
      expect(response).to be_success
    end
  end

  describe "#generate_translator_report" do
    before do
      @start_date = Date.today
      @end_date = @start_date.next_month
      @languages = ['fr', 'it']
      @exclude_internal = true
    end

    it 'has a response of 400 if start_date is nil' do
      post :generate_translator_report, format: :csv, start_date: nil, end_date: @end_date.strftime('%m/%d/%Y'), languages: @languages
      expect(response.status).to eq 400
    end

    it 'has a response of 400 if if end_date is nil' do
      post :generate_translator_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: nil, languages: @languages
      expect(response.status).to eq 400
    end

    it 'throws an exception if end_date is before start_date' do
      post :generate_translator_report, format: :csv, start_date: @end_date.strftime('%m/%d/%Y'), end_date: @start_date.strftime('%m/%d/%Y'), languages: @languages
      expect(response.status).to eq 400
    end

    it 'throws an exception if languages is not an array' do
      post :generate_translator_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: @end_date.strftime('%m/%d/%Y'), languages: 'fr'
      expect(response.status).to eq 400
    end

    it 'sends a csv file to the client' do
      post :generate_translator_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: @end_date.strftime('%m/%d/%Y'), languages: @languages
      expect(response).to be_success
    end
  end

  describe "#generate_backlog_report" do
    before do
      @start_date = Date.today
      @end_date = @start_date.next_month
    end

    it 'has a response of 400 if start_date is nil' do
      post :generate_backlog_report, format: :csv, start_date: nil, end_date: @end_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'has a response of 400 if if end_date is nil' do
      post :generate_backlog_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: nil
      expect(response.status).to eq 400
    end

    it 'throws an exception if end_date is before start_date' do
      post :generate_backlog_report, format: :csv, start_date: @end_date.strftime('%m/%d/%Y'), end_date: @start_date.strftime('%m/%d/%Y')
      expect(response.status).to eq 400
    end

    it 'sends a csv file to the client' do
      post :generate_backlog_report, format: :csv, start_date: @start_date.strftime('%m/%d/%Y'), end_date: @end_date.strftime('%m/%d/%Y')
      expect(response).to be_success
    end
  end
end
