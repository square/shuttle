# encoding: utf-8

# Copyright 2013 Square Inc.
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

describe GlossaryEntriesController do
  before :each do
    @user = FactoryGirl.create(:user, role: 'admin')
    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in @user
  end

  describe '#index' do
    it "should return glossary entries for that locale, and ensure they exist" do
      ge = GlossaryEntry.new
      ge.source_copy = "hello"
      ge.copy = "world"
      ge.source_rfc5646_locale = 'en'
      ge.rfc5646_locale = 'en'
      ge.save

      get :index, locale_id: 'fr'
      entries = GlossaryEntry.where(rfc5646_locale: 'fr')
      response.body.should == entries.to_json
      entries.size.should == 1
    end

    it "should return sorted glossary entries" do
      FactoryGirl.create :glossary_entry, source_copy: "Apple", copy: "Apfel"
      FactoryGirl.create :glossary_entry, source_copy: "Center", copy: "Zentrum"
      FactoryGirl.create :glossary_entry, source_copy: "Bicycle", copy: "Fahrrad"

      get :index, locale_id: 'de-DE'
      body = JSON.parse(response.body)
      body.map { |ge| ge['source_copy'] }.should eql(%w(Apple Bicycle Center))
    end
  end

  describe '#create' do
    it "should create a glossary entry." do
      lambda {
        post(:create, source_copy: "something", locale_id: 'fr')
        response.body.should == "true"
      }.should(change(GlossaryEntry, :count).by(1))
    end
  end

  describe '#update' do
    let :entry do
      ge = GlossaryEntry.new
      ge.source_copy = "hello"
      ge.copy = "world"
      ge.source_rfc5646_locale = 'en'
      ge.rfc5646_locale = 'fr'
      ge.approved = true
      ge.reviewer_id = @user.id
      ge.save
      ge
    end
    it "should only update reviewer_id if that was approved was passed as a param." do
      patch :update, id: entry.id, copy: "goodbye", locale_id: 'fr'
      entry.reload
      entry.copy.should == "goodbye"
      entry.approved.should == nil
      entry.reviewer_id.should == nil

      patch :update, id: entry.id, copy: "goodbye", approved: "true", review: true, locale_id: 'fr'
      entry.reload
      entry.approved.should == true
      entry.reviewer_id.should == @user.id
    end
  end
end
