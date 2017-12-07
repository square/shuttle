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

RSpec.describe Locale::ProjectsController do
  describe "#show" do
    context "[status filtering]" do
      before :each do
        reset_elastic_search
        @user    = FactoryBot.create(:user, :confirmed, role: 'translator', approved_rfc5646_locales: ['fr-CA'])
        @project = FactoryBot.create(:project, base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: {'fr-CA' => true})

        @translated_key = FactoryBot.create(:key, project: @project)
        @approved_key   = FactoryBot.create(:key, project: @project)
        @rejected_key   = FactoryBot.create(:key, project: @project)
        @new_key        = FactoryBot.create(:key, project: @project)

        @translated_base = FactoryBot.create(:translation,
                                              key:                   @translated_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)
        @approved_base   = FactoryBot.create(:translation,
                                              key:                   @approved_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)
        @rejected_base   = FactoryBot.create(:translation,
                                              key:                   @rejected_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)
        @new_base        = FactoryBot.create(:translation,
                                              key:                   @new_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)

        @translated = FactoryBot.create(:translation,
                                         key:                   @translated_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         translated:            true,
                                         approved:              nil)
        @approved   = FactoryBot.create(:translation,
                                         key:                   @approved_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         translated:            true,
                                         approved:              true)
        @rejected   = FactoryBot.create(:translation,
                                         key:                   @rejected_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         translated:            true,
                                         approved:              false)
        @new        = FactoryBot.create(:translation,
                                         key:                   @new_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         copy:                  nil,
                                         translated:            false,
                                         approved:              nil)
        regenerate_elastic_search_indexes

        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in @user
      end

      it "should filter with include_translated = true and include_new = true if noe include_ are specified" do
        get :show, id: @project.to_param, locale_id: 'fr-CA'
        expect(response.status).to eql (200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }).to match_array([@translated.key.key, @new.key.key, @rejected.key.key])

      end

      it "should filter with include_translated = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_translated: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }).to match_array([@translated.key.key])
      end

      it "should filter with include_approved = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_approved: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }.sort).
            to eql([@approved.key.key].sort)
      end

      it "should filter with include_new = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }.sort).
            to eql([@new.key.key, @rejected.key.key].sort)
      end

      it "should filter with include_translated = true, include_new = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_translated: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }.sort).
            to eql([@translated.key.key, @new.key.key, @rejected.key.key].sort)
      end

      it "should filter with include_approved = true, include_new = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_approved: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }.sort).
            to eql([@approved.key.key, @new.key.key].sort)
      end

      it "should filter with include_translated = true, include_approved = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_translated: 'true', include_approved: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }.sort).
            to eql([@translated.key.key, @approved.key.key, @rejected.key.key].sort)
      end

      it "should filter with include_translated = true, include_approved = true, include_new = true" do
        get :show, id: @project.to_param, locale_id: 'fr-CA', include_translated: 'true', include_approved: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.key.key }.sort).
            to eql([@translated.key.key, @approved.key.key, @rejected.key.key, @new.key.key].sort)
      end

      it "should filter with commit" do
        commit = FactoryBot.create(:commit, project: @project)
        commit.keys << @new_key
        get :show, id: @project.to_param, locale_id: 'fr-CA', commit: commit.revision, include_translated: 'true', include_approved: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.first.key.key).to eql(@new.key.key)
      end
    end

    context "[Article-specific]" do
      before :each do
        user = FactoryBot.create(:user, :confirmed, role: 'translator', approved_rfc5646_locales: ['fr'])
        request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in user

        allow_any_instance_of(Article).to receive(:import!) # prevent auto import
        reset_elastic_search

        @project = FactoryBot.create(:project, repository_url: nil)
        @article = FactoryBot.create(:article, project: @project)
        @section1 = FactoryBot.create(:section, article: @article)
        @section2 = FactoryBot.create(:section, article: @article)
        @key1 = FactoryBot.create(:key, section: @section1, index_in_section: 0, project: @project)
        @key2 = FactoryBot.create(:key, section: @section1, index_in_section: 1, project: @project)
        @key3 = FactoryBot.create(:key, section: @section1, index_in_section: 2, project: @project)
        @key4 = FactoryBot.create(:key, section: @section2, index_in_section: 0, project: @project)
        @key5 = FactoryBot.create(:key, section: @section2, index_in_section: 1, project: @project, source_copy: '<p>')
        @translation1 = FactoryBot.create(:translation, key: @key1, copy: nil, rfc5646_locale: 'fr')
        @translation2 = FactoryBot.create(:translation, key: @key2, copy: nil, rfc5646_locale: 'fr')
        @translation3 = FactoryBot.create(:translation, key: @key3, copy: nil, rfc5646_locale: 'fr')
        @translation4 = FactoryBot.create(:translation, key: @key4, copy: nil, rfc5646_locale: 'fr')
        @translation5 = FactoryBot.create(:translation, key: @key5, copy: nil, rfc5646_locale: 'fr')

        regenerate_elastic_search_indexes
      end

      it "returns active keys in an article in the right order" do
        @section2.update! active: false     # inactive section
        @key3.update! index_in_section: nil # inactive key
        regenerate_elastic_search_indexes

        get :show, id: @project.to_param, article_id: @article.id, locale_id: 'fr', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.id }).to eql([@translation1.id, @translation2.id])
      end

      it "filters with section_id" do
        get :show, id: @project.to_param, article_id: @article.id, section_id: @section2.id, locale_id: 'fr', include_new: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.id }).to eql([@translation4.id])
      end

      it "filters with include_block_tags" do
        get :show, id: @project.to_param, article_id: @article.id, section_id: @section2.id, locale_id: 'fr', include_new: 'true', include_block_tags: 'true'
        expect(response.status).to eql(200)
        translations = assigns(:translations)
        expect(translations.map { |t| t.id }).to eql([@translation4.id, @translation5.id])
      end
    end
  end
end
