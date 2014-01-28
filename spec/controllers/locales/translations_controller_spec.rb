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

describe Locale::TranslationsController do
  describe "#index" do
    context "[filtering]" do
      before :all do
        reset_elastic_search
        @user    = FactoryGirl.create(:user, role: 'translator')
        @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: {'fr-CA' => true})

        @translated_key = FactoryGirl.create(:key, project: @project)
        @approved_key   = FactoryGirl.create(:key, project: @project)
        @rejected_key   = FactoryGirl.create(:key, project: @project)
        @new_key        = FactoryGirl.create(:key, project: @project)

        @translated_base = FactoryGirl.create(:translation,
                                              key:                   @translated_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)
        @approved_base   = FactoryGirl.create(:translation,
                                              key:                   @approved_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)
        @rejected_base   = FactoryGirl.create(:translation,
                                              key:                   @rejected_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)
        @new_base        = FactoryGirl.create(:translation,
                                              key:                   @new_key,
                                              source_rfc5646_locale: 'en-US',
                                              rfc5646_locale:        'en-US',
                                              translated:            true,
                                              approved:              true)

        @translated = FactoryGirl.create(:translation,
                                         key:                   @translated_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         translated:            true,
                                         approved:              nil)
        @approved   = FactoryGirl.create(:translation,
                                         key:                   @approved_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         translated:            true,
                                         approved:              true)
        @rejected   = FactoryGirl.create(:translation,
                                         key:                   @rejected_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         translated:            true,
                                         approved:              false)
        @new        = FactoryGirl.create(:translation,
                                         key:                   @new_key,
                                         source_rfc5646_locale: 'en-US',
                                         rfc5646_locale:        'fr-CA',
                                         copy:                  nil,
                                         translated:            false,
                                         approved:              nil)
        regenerate_elastic_search_indexes
      end

      before :each do
        @request.env["devise.mapping"] = Devise.mappings[:user]
        sign_in @user
        sleep(2)
      end

      it "should filter with no options" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body)).to eql([])
      end

      it "should filter with include_translated = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_translated: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@translated.key.key].sort)
      end

      it "should filter with include_approved = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_approved: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@approved.key.key].sort)
      end

      it "should filter with include_new = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_new: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@new.key.key, @rejected.key.key].sort)
      end

      it "should filter with include_translated = true, include_new = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_translated: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@translated.key.key, @new.key.key, @rejected.key.key].sort)
      end

      it "should filter with include_approved = true, include_new = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_approved: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@approved.key.key, @new.key.key].sort)
      end

      it "should filter with include_translated = true, include_approved = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_translated: 'true', include_approved: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@translated.key.key, @approved.key.key, @rejected.key.key].sort)
      end

      it "should filter with include_translated = true, include_approved = true, include_new = true" do
        get :index, project_id: @project.to_param, locale_id: 'fr-CA', format: 'json', include_translated: 'true', include_approved: 'true', include_new: 'true'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |t| t['key']['key'] }.sort).
            to eql([@translated.key.key, @approved.key.key, @rejected.key.key, @new.key.key].sort)
      end
    end
  end
end
