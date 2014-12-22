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
      Article.any_instance.stub(:import!) # prevent auto import

      reset_elastic_search
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, :confirmed, role: 'monitor')
      sign_in @user

      @project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'ja'=>true, 'es'=>false}, base_rfc5646_locale: 'en')
      @commit = FactoryGirl.create(:commit, project: @project)
      @commit_key = FactoryGirl.create(:key, project: @project)
      @commit.keys << @commit_key

      @article = FactoryGirl.create(:article, project: @project)
      @section = FactoryGirl.create(:section, article: @article)
      @article_key = FactoryGirl.create(:key, section: @section, index_in_section: 0)

      regenerate_elastic_search_indexes
      sleep(2)
    end

    it "returns the commit/article with pending translations in specified locales, even if that commit/article is ready and the locale is optional" do
      FactoryGirl.create(:translation, key: @commit_key, rfc5646_locale: 'es', source_rfc5646_locale: 'en')
      @commit_key.update_columns ready: true
      @commit.update_columns ready: true

      FactoryGirl.create(:translation, key: @article_key, rfc5646_locale: 'es', source_rfc5646_locale: 'en')
      @article_key.update_columns ready: true
      @article.update_columns ready: true

      get :index, { filter__rfc5646_locales: 'es', filter__status: 'uncompleted' }
      expect(assigns(:commits).map(&:id)).to eq([@commit.id])
      expect(assigns(:articles).map(&:id)).to eq([@article.id])
    end

    it "doesn't return the commit/article with no pending translations in specified locales, even if that commit/article is not ready and the locale is required" do
      FactoryGirl.create(:translation, key: @commit_key, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true)
      @commit_key.update_columns ready: false
      @commit.update_columns ready: false

      FactoryGirl.create(:translation, key: @article_key, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true)
      @article_key.update_columns ready: false
      @article.update_columns ready: false

      get :index, { filter__rfc5646_locales: 'ja', filter__status: 'uncompleted' }
      expect(assigns(:commits).map(&:id)).to eq([])
      expect(assigns(:articles).map(&:id)).to eq([])
    end
  end
end
