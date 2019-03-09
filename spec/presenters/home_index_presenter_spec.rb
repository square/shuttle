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

require 'rails_helper'

RSpec.describe HomeIndexPresenter do
  before :each do
    allow_any_instance_of(Article).to receive(:import!) # prevent auto imports
    @presenter = HomeIndexPresenter.new([], [], [], [], [])
  end

  describe "#full_description" do
    context "[Commit]" do
      it "returns full description" do
        commit = FactoryBot.create(:commit, description: 'abc'*50)
        expect(@presenter.full_description(commit)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        commit = FactoryBot.create(:commit, description: nil)
        expect(@presenter.full_description(commit)).to eql('-')
      end

      it "strips html from descriptions with html in them" do
        commit = FactoryBot.create(:commit, description: '<a href="/cool/site">you must be <strong>swift as the</strong></a><br/> coursing river')
        expect(@presenter.full_description(commit)).to eql('you must be swift as the coursing river')
      end
    end

    context "[Article]" do
      it "returns full description" do
        article = FactoryBot.create(:article, description: 'abc'*50)
        expect(@presenter.full_description(article)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        article = FactoryBot.create(:article, description: nil)
        expect(@presenter.full_description(article)).to eql('-')
      end

      it "strips html from descriptions with html in them" do
        article = FactoryBot.create(:article, description: '<a href="/cool/site">with all the <strong>force of a</strong></a><br/> great typhoon')
        expect(@presenter.full_description(article)).to eql('with all the force of a great typhoon')
      end
    end

    context "[Group]" do
      it "returns full description" do
        group = FactoryBot.create(:group, name: 'full-description-group', description: 'abc'*50)
        expect(@presenter.full_description(group)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        group = FactoryBot.create(:group, name: 'dash-description-group', description: nil)
        expect(@presenter.full_description(group)).to eql('-')
      end
    end

    context "[Asset]" do
      it "returns full description" do
        asset = FactoryBot.create(:asset, description: 'abc'*50)
        expect(@presenter.full_description(asset)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        asset = FactoryBot.create(:asset, description: nil)
        expect(@presenter.full_description(asset)).to eql('-')
      end

      it "strips html from descriptions with html in them" do
        asset = FactoryBot.create(:asset, description: '<a href="/cool/site">with all the <strong>force of a</strong></a><br/> great typhoon')
        expect(@presenter.full_description(asset)).to eql('with all the force of a great typhoon')
      end
    end
  end

  describe "#short_description" do
    context "[Commit]" do
      it "returns a truncated description" do
        commit = FactoryBot.create(:commit, description: 'abc'*50)
        expect(@presenter.short_description(commit)).to eql('abc'*15 + 'ab...')
      end

      it "strips html from descriptions with html in them and only shortens the non-html content" do
        commit = FactoryBot.create(:commit, description: '<a href="/cool/site">with all the <strong>strength</strong> of a <em>raging fire</em>, mysterious| as the dark side of the moon</a>')
        expect(@presenter.short_description(commit)).to eql('with all the strength of a raging fire, mysteri...')
      end
    end

    context "[Article]" do
      it "returns full description" do
        article = FactoryBot.create(:article, description: 'abc'*50)
        expect(@presenter.full_description(article)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        article = FactoryBot.create(:article, description: nil)
        expect(@presenter.full_description(article)).to eql('-')
      end

      it "strips html from descriptions with html in them" do
        article = FactoryBot.create(:article, description: '<a href="/cool/site">with all the <strong>force of a</strong></a><br/> great typhoon')
        expect(@presenter.full_description(article)).to eql('with all the force of a great typhoon')
      end
    end

    context "[Group]" do
      it "returns full description" do
        group = FactoryBot.create(:group, name: 'full-description-group', description: 'abc'*50)
        expect(@presenter.full_description(group)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        group = FactoryBot.create(:group, name: 'dash-description-group', description: nil)
        expect(@presenter.full_description(group)).to eql('-')
      end
    end

    context "[Asset]" do
      it "returns full description" do
        asset = FactoryBot.create(:asset, description: 'abc'*50)
        expect(@presenter.full_description(asset)).to eql('abc'*50)
      end

      it "returns a dash sign if description is missing" do
        asset = FactoryBot.create(:asset, description: nil)
        expect(@presenter.full_description(asset)).to eql('-')
      end

      it "strips html from descriptions with html in them" do
        asset = FactoryBot.create(:asset, description: '<a href="/cool/site">with all the <strong>force of a</strong></a><br/> great typhoon')
        expect(@presenter.full_description(asset)).to eql('with all the force of a great typhoon')
      end
    end
  end
  describe "#sub_description" do
    context "[Commit]" do
      it "returns a description to display under the main description" do
        commit = FactoryBot.create(:commit, author: 'foo bar')
        expect(@presenter.sub_description(commit)).to eql('Authored By: foo bar')
      end
    end

    context "[Article]" do
      it "returns empty string" do
        article = FactoryBot.create(:article)
        expect(@presenter.sub_description(article)).to eql('')
      end
    end

    context "[Group]" do
      it "returns empty string" do
        group = FactoryBot.create(:group, name: 'full-description-group')
        expect(@presenter.sub_description(group)).to eql('')
      end
    end

    context "[Asset]" do
      it "returns empty string" do
        asset = FactoryBot.create(:asset)
        expect(@presenter.sub_description(asset)).to eql('')
      end
    end
  end

  describe "#update_item_path" do
    context "[Commit]" do
      it "returns the commit update path" do
        commit = FactoryBot.create(:commit)
        expect(@presenter.update_item_path(commit)).to eql(Rails.application.routes.url_helpers.project_commit_path(commit.project, commit, format: 'json'))
      end
    end

    context "[Article]" do
      it "returns the article update path" do
        article = FactoryBot.create(:article)
        expect(@presenter.update_item_path(article)).to eql(Rails.application.routes.url_helpers.api_v1_project_article_path(project_id: article.project_id, name: article.name, format: 'json'))
      end
    end

    context "[Group]" do
      it "returns the group update path" do
        group = FactoryBot.create(:group, name: 'full-description-group')
        expect(@presenter.update_item_path(group)).to eql(Rails.application.routes.url_helpers.api_v1_project_group_path(project_id: group.project_id, name: group.name, format: 'json'))
      end
    end

    context "[Asset]" do
      it "returns the article update path" do
        asset = FactoryBot.create(:asset)
        expect(@presenter.update_item_path(asset)).to eql(Rails.application.routes.url_helpers.project_asset_path(asset.project,asset, format: 'json'))
      end
    end
  end

  describe "#translate_link_path" do
    before :each do
      @url_helpers = Rails.application.routes.url_helpers
      @project = FactoryBot.create(:project, targeted_rfc5646_locales: {'en-CA'=>true, 'fr'=> true, 'ja'=> true })
      @admin_user = FactoryBot.create(:user, :admin, approved_rfc5646_locales: [])
      @reviewer_user = FactoryBot.create(:user, :reviewer, approved_rfc5646_locales: %w(es fr))
    end

    context "[Commit]" do
      it "returns the commit translate link path" do
        commit = FactoryBot.create(:commit, project: @project)
        expect(@presenter.translate_link_path(@admin_user, commit)).
            to eql(@url_helpers.locale_project_path(locale_id: 'en-CA', id: commit.project, commit: commit.revision))
        expect(@presenter.translate_link_path(@reviewer_user, commit)).
            to eql(@url_helpers.locale_project_path(locale_id: 'fr', id: commit.project, commit: commit.revision))
      end
    end

    context "[Article]" do
      it "returns the article translate link path" do
        article = FactoryBot.create(:article, project: @project)
        expect(@presenter.translate_link_path(@admin_user, article)).
            to eql(@url_helpers.locale_project_path(locale_id: 'en-CA', id: article.project, article_id: article.id))
        expect(@presenter.translate_link_path(@reviewer_user, article)).
            to eql(@url_helpers.locale_project_path(locale_id: 'fr', id: article.project, article_id: article.id))
      end
    end

    context "[Group]" do
      it "returns the group translate link path" do
        group = FactoryBot.create(:group, name: 'full-description-group', project: @project)
        expect(@presenter.translate_link_path(@admin_user, group)).
            to eql(@url_helpers.locale_project_path(locale_id: 'en-CA', id: group.project, group: group.display_name))
        expect(@presenter.translate_link_path(@reviewer_user, group)).
            to eql(@url_helpers.locale_project_path(locale_id: 'fr', id: group.project, group: group.display_name))
      end
    end

    context "[Asset]" do
      it "returns the asset translate link path" do
        asset = FactoryBot.create(:asset, project: @project)
        expect(@presenter.translate_link_path(@admin_user, asset)).
            to eql(@url_helpers.locale_project_path(locale_id: 'en-CA', id: asset.project, asset_id: asset.id))
        expect(@presenter.translate_link_path(@reviewer_user, asset)).
            to eql(@url_helpers.locale_project_path(locale_id: 'fr', id: asset.project, asset_id: asset.id))
      end
    end
  end
end
