# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicabcle law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe HomeIndexPresenter do
  before :each do
    Article.any_instance.stub(:import!) # prevent auto imports
    @presenter = HomeIndexPresenter.new([], [], [])
  end

  describe "#full_description" do
    context "[Commit]" do
      it "returns full description" do
        commit = FactoryGirl.create(:commit, description: 'abc'*50)
        expect(@presenter.full_description(commit)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        commit = FactoryGirl.create(:commit, description: nil)
        expect(@presenter.full_description(commit)).to eql('-')
      end
    end

    context "[Article]" do
      it "returns full description" do
        article = FactoryGirl.create(:article, description: 'abc'*50)
        expect(@presenter.full_description(article)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        article = FactoryGirl.create(:article, description: nil)
        expect(@presenter.full_description(article)).to eql('-')
      end
    end
  end

  describe "#short_description" do
    context "[Commit]" do
      it "returns a truncated description" do
        commit = FactoryGirl.create(:commit, description: 'abc'*50)
        expect(@presenter.short_description(commit)).to eql('abc'*15 + 'ab...')
      end
    end

    context "[Article]" do
      it "returns a truncated description" do
        article = FactoryGirl.create(:article, description: 'abc'*50)
        expect(@presenter.short_description(article)).to eql('abc'*15 + 'ab...')
      end
    end
  end

  describe "#sub_description" do
    context "[Commit]" do
      it "returns a description to display under the main description" do
        commit = FactoryGirl.create(:commit, author: 'foo bar')
        expect(@presenter.sub_description(commit)).to eql('Authored By: foo bar')
      end
    end

    context "[Article]" do
      it "returns empty string" do
        article = FactoryGirl.create(:article)
        expect(@presenter.sub_description(article)).to eql('')
      end
    end
  end

  describe "#update_item_path" do
    context "[Commit]" do
      it "returns the commit update path" do
        commit = FactoryGirl.create(:commit)
        expect(@presenter.update_item_path(commit)).to eql(Rails.application.routes.url_helpers.project_commit_path(commit.project, commit, format: 'json'))
      end
    end

    context "[Article]" do
      it "returns the article update path" do
        article = FactoryGirl.create(:article)
        expect(@presenter.update_item_path(article)).to eql(Rails.application.routes.url_helpers.api_v1_project_article_path(project_id: article.project_id, name: article.name, format: 'json'))
      end
    end
  end
end
