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

require 'spec_helper'

describe StatsController do
  before do
    Translation.delete_all
    user = FactoryGirl.create(:user, :activated)
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user
  end

  describe "#index" do
    context "format: html" do
      before do
        FactoryGirl.create :daily_metric, date: 5.days.ago
        FactoryGirl.create :daily_metric, date: 10.days.ago
        FactoryGirl.create :translation
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
        FactoryGirl.create(:commit,
                           loading: false,
                           created_at: created_at,
                           loaded_at: loaded_at)
        FactoryGirl.create(:commit, loading: true)
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
end
