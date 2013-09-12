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

describe SourceGlossaryEntry do
  before :each do
    @user = FactoryGirl.create(:user, role: 'admin')
  end

  describe '#' do
  #   it "sets reviewer_id to false unless specifically changed" do
  #     ge = GlossaryEntry.new
  #     ge.source_copy = "hello"
  #     ge.copy = "world"
  #     ge.source_rfc5646_locale = 'en'
  #     ge.rfc5646_locale = 'fr'
  #     ge.reviewer_id = @user.id
  #     ge.save

  #     ge.copy = "goodbye"
  #     ge.save

  #     ge.reviewer_id.should == nil
  #     ge.approved.should be_false
  #   end
  #   it "does not set reviewer_id if specifically changed." do
  #     ge = GlossaryEntry.new
  #     ge.source_copy = "hello"
  #     ge.copy = "world"
  #     ge.source_rfc5646_locale = 'en'
  #     ge.rfc5646_locale = 'fr'
  #     ge.reviewer_id = @user.id
  #     ge.save

  #     ge.approved = true

  #     ge.save

  #     ge.reviewer_id.should == @user.id
  #     ge.approved.should be_true
  #   end
  # end
  # describe '.ensure_entries_exist_in_locale' do
  #   it "does nothing if all entries already exist." do
  #     ['en', 'fr'].each do |locale|
  #       ge = GlossaryEntry.new
  #       ge.source_copy = "hello"
  #       ge.copy = "world"
  #       ge.source_rfc5646_locale = "en"
  #       ge.rfc5646_locale = locale
  #       ge.save
  #     end
  #     lambda {
  #       GlossaryEntry.ensure_entries_exist_in_locale('fr')
  #     }.should_not change(GlossaryEntry, :count)
  #   end
  #   it "creates non-existing glossary entries" do
  #     ge = GlossaryEntry.new
  #     ge.source_copy = "hello"
  #     ge.copy = "world"
  #     ge.source_rfc5646_locale = "en"
  #     ge.rfc5646_locale = "en"
  #     ge.save

  #     lambda {
  #       GlossaryEntry.ensure_entries_exist_in_locale('fr')
  #     }.should change(GlossaryEntry, :count).by(1)
  #   end
  end
end
