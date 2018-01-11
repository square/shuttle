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

RSpec.describe HomeController do
  before :each do
    allow_any_instance_of(Article).to receive(:import!) # prevent auto import

    reset_elastic_search
    @request.env['devise.mapping'] = Devise.mappings[:user]
    @user = FactoryBot.create(:user, :confirmed, role: 'monitor')
    sign_in @user

    @project = FactoryBot.create(:project, targeted_rfc5646_locales: {'ja'=>true, 'es'=>false}, base_rfc5646_locale: 'en')
    @commit = FactoryBot.create(:commit, project: @project)
    @commit_key = FactoryBot.create(:key, project: @project)
    @commit.keys << @commit_key

    @article = FactoryBot.create(:article, project: @project)
    @section = FactoryBot.create(:section, article: @article)
    @article_key = FactoryBot.create(:key, section: @section, index_in_section: 0)

    # red herring: loading commit
    FactoryBot.create(:commit, project: @project, loading: true)

    regenerate_elastic_search_indexes
  end

  context "[when 'uncompleted' filter is selected and locales are specified]" do
    it "returns the commit/article with pending translations in specified locales, even if that commit/article is ready and the locale is optional" do
      FactoryBot.create(:translation, key: @commit_key, rfc5646_locale: 'es', source_rfc5646_locale: 'en')
      @commit_key.update_columns ready: true
      @commit.update_columns ready: true

      FactoryBot.create(:translation, key: @article_key, rfc5646_locale: 'es', source_rfc5646_locale: 'en')
      @article_key.update_columns ready: true
      @article.update_columns ready: true

      get :index, { filter__rfc5646_locales: 'es', filter__status: 'uncompleted' }
      expect(assigns(:commits).map(&:id)).to eq([@commit.id])
      expect(assigns(:articles).map(&:id)).to eq([@article.id])
    end

    it "doesn't return the commit/article with no pending translations in specified locales, even if that commit/article is not ready and the locale is required" do
      FactoryBot.create(:translation, key: @commit_key, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true)
      @commit_key.update_columns ready: false
      @commit.update_columns ready: false

      FactoryBot.create(:translation, key: @article_key, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true)
      @article_key.update_columns ready: false
      @article.update_columns ready: false

      get :index, { filter__rfc5646_locales: 'ja', filter__status: 'uncompleted' }
      expect(assigns(:commits).map(&:id)).to eq([])
      expect(assigns(:articles).map(&:id)).to eq([])
    end

    it "should return all hidden articles" do
      hidden_article = FactoryBot.create(:article, project: @project, hidden: true)

      get :index, { filter__status: 'hidden' }
      expect(assigns(:articles).map(&:id)).to eq([hidden_article.id])
    end
  end

  context "[when only 'all translations' and 'all projects' filters are selected]" do
    it 'should return all translations in all projects' do
      commit1 = FactoryBot.create(:commit, project: @project, ready: false)
      commit2 = FactoryBot.create(:commit, project: @project)
      regenerate_elastic_search_indexes

      get :index, { filter__status: 'all', commits_filter__project_id: 'all' }
      expect(assigns(:commits).map(&:id)).to eq([commit2.id, commit1.id, @commit.id])
    end
  end
end
