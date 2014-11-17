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

describe TranslationObserver do
  context "[translation changes]" do
    before :each do
      @trans = FactoryGirl.create(:translation)
    end

    it "should log the change and the changer when a user changes the translation" do
      old_copy   = @trans.copy
      new_copy   = "A new translation"
      translator = FactoryGirl.create(:user)
      expect {
        @trans.freeze_tracked_attributes
        @trans.copy     = new_copy
        @trans.modifier = translator
        @trans.save
      }.to change { TranslationChange.count }.by(1)
      change = TranslationChange.last
      expect(change.diff).to eq({"copy" => [old_copy, new_copy]})
      expect(change.user).to eq(translator)
    end

    it "should log the approval and the approver when a user approves the translation" do
      approver = FactoryGirl.create(:user)
      expect {
        @trans.freeze_tracked_attributes
        @trans.approved = true
        @trans.modifier = approver
        @trans.save
      }.to change { TranslationChange.count }.by(1)
      change = TranslationChange.last
      expect(change.diff).to eq({"approved" => [nil, true]})
      expect(change.user).to eq(approver)
    end

    it "should not log a change when a field we don't care about changes" do
      expect {
        @trans.freeze_tracked_attributes
        @trans.updated_at = Time.now
        @trans.save
      }.to_not change { TranslationChange.count }
    end

    it "should not log a user when the computer modifies the Translation" do
      expect {
        @trans.freeze_tracked_attributes
        @trans.copy = "A new translation"
        @trans.save
      }.to change { TranslationChange.count }.by(1)
      change = TranslationChange.last
      expect(change.user).to eq(nil)
    end
  end

  context "[translation memory]" do
    before :each do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation, source_rfc5646_locale: 'en', rfc5646_locale: 'de', source_copy: "test", copy: nil)
      expect(TranslationUnit.source_copy_matches("test").where(source_rfc5646_locale: "en", rfc5646_locale: "de").exists?).to be_false
    end

    it "create a new TranslationUnit when a translator translates and approves a Translation" do
      @translation.update! copy: "test", approved: true, modifier: @user
      tu = TranslationUnit.exact_matches(@translation).first
      expect(tu.copy).to eql(@translation.copy)
      expect(tu.locale).to eql(@translation.locale)
    end

    it "doesn't create a new TranslationUnit if a Translation is translated and approved automatically without a user (ex: mass copied from another locale)" do
      @translation.update! copy: "test", approved: true
      expect(TranslationUnit.source_copy_matches("test").where(source_rfc5646_locale: "en", rfc5646_locale: "de").exists?).to be_false
    end

    it "doesn't update the translation memory when translated but not approved" do
      translation = FactoryGirl.create(:translation, approved: nil)
      translation.update! copy: "test", translator: @user, modifier: @user
      expect(TranslationUnit.exact_matches(@translation)).to be_empty
    end
  end
end
