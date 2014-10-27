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

describe HomeController do
  context "[when 'uncompleted' filter is selected and locales are specified]" do
    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, :confirmed, role: 'monitor')
      sign_in @user

      @project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'ja'=>true, 'es'=>false}, base_rfc5646_locale: 'en')
      @commit = FactoryGirl.create(:commit, project: @project)
      @key = FactoryGirl.create(:key, project: @project)
      @commit.keys << @key

      regenerate_elastic_search_indexes
      sleep(2)
    end

    it "returns the commit with pending translations in specified locales, even if that commit is ready and the locale is optional" do
      FactoryGirl.create(:translation, key: @key, rfc5646_locale: 'es', source_rfc5646_locale: 'en')
      @key.update_columns ready: true
      @commit.update_columns ready: true

      get :index, { locales: 'es', status: 'uncompleted', exported: "true", show_autoimport: "true" }
      expect(assigns(:commits).map(&:id)).to eq([@commit.id])
    end

    it "doesn't return the commit with no pending translations in specified locales, even if that skipped commit is not ready and the locale is required" do
      FactoryGirl.create(:translation, key: @key, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true)
      @key.update_columns ready: false
      @commit.update_columns ready: false

      get :index, { locales: 'ja', status: 'uncompleted', exported: "true", show_autoimport: "true" }
      expect(assigns(:commits).map(&:id)).to eq([])
    end
  end
end
