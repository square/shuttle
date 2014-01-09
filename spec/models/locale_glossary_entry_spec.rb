# encoding: utf-8

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

describe LocaleGlossaryEntry do
  context "[hooks]" do
    before :each do
      reviewer = FactoryGirl.create(:user, role: 'reviewer')
      @lge = FactoryGirl.create(:locale_glossary_entry, approved: false, reviewer: reviewer)
    end

    it "should revert the approved status if the copy is changed" do
      @lge.update_attribute :copy, "new copy"
      expect(@lge).not_to be_approved
      expect(@lge.reviewer).to be_nil
    end

    it "should not revert the approved status if the approved status and copy are changed simultaneously" do
      @lge.update_attributes copy: "new copy", approved: true
      expect(@lge).to be_approved
      expect(@lge.reviewer).not_to be_nil
    end
  end

  context "[validations]" do
    it "should not allow a translator to change the approved status" do
      translator = FactoryGirl.create(:user, role: 'translator')
      lge = FactoryGirl.create(:locale_glossary_entry, approved: nil)
      lge.assign_attributes approved: true, translator: translator
      expect(lge).not_to be_valid
      expect(lge.errors[:base]).to eql(["Translators can’t change a translation that has been approved."])
    end

    it "should ensure the source and target locales are different" do
      lge = FactoryGirl.build(:locale_glossary_entry, rfc5646_locale: 'en')
      expect(lge).not_to be_valid
      expect(lge.errors[:rfc5646_locale]).to eql(["can’t equal source locale"])
    end
  end
end
