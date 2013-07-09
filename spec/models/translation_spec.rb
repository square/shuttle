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

describe Translation do
  context "[hooks]" do
    before :all do
      @key = FactoryGirl.create(:key, project: FactoryGirl.create(:project,
                                                                  targeted_rfc5646_locales: {'en' => true, 'de' => true}))
      FactoryGirl.create :translation, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true, key: @key
      @commit      = FactoryGirl.create(:commit, project: @key.project)
      @commit.keys = [@key]
    end

    context "[readiness recalculation]" do
      it "should recalculate the readiness of all affected commits when added" do
        FactoryGirl.create :translation, key: @key, rfc5646_locale: 'de', approved: true
        @key.reload.should be_ready
        @commit.reload.should be_ready
      end

      it "should recalculate the readiness of all affected commits when modified" do
        trans = FactoryGirl.create(:translation, key: @key, rfc5646_locale: 'de', approved: true)
        trans.update_attribute :approved, false
        @key.reload.should_not be_ready
        @commit.reload.should_not be_ready
      end
    end

    context "[resetting reviewed state]" do
      it "should reset the reviewed state when the copy is changed" do
        trans = FactoryGirl.create(:translation, approved: true, reviewer: FactoryGirl.create(:user))
        trans.update_attribute :copy, "New copy"
        trans.reviewer_id.should be_nil
        trans.approved.should be_nil
      end

      it "should not reset the reviewed state when the copy is not changed" do
        trans = FactoryGirl.create(:translation, approved: true, reviewer: FactoryGirl.create(:user))
        trans.update_attribute :translator, FactoryGirl.create(:user)
        trans.reviewer_id.should_not be_nil
        trans.approved.should eql(true)
      end

      it "should not reset the reviewed state if the reviewed state is changed along with the copy" do
        trans = FactoryGirl.create(:translation, approved: false, reviewer: FactoryGirl.create(:user))
        trans.update_attributes(copy: "New copy", approved: true)
        trans.reviewer_id.should_not be_nil
        trans.approved.should eql(true)
      end
    end

    it "should set translated to true upon translation" do
      trans = FactoryGirl.create(:translation, copy: nil)
      trans.should_not be_translated
      trans.update_attribute :copy, "foo"
      trans.should be_translated
    end

    context "[automatically setting reviewed]" do
      before :all do
        @key      = FactoryGirl.create(:key)
        @reviewer = FactoryGirl.create(:user, role: 'reviewer')
      end
      before(:each) { @translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, reviewer: nil) }

      it "should automatically mark as reviewed translations made by a translator" do
        @translation.translator = @reviewer
        @translation.copy       = 'foobar'
        @translation.save!
        @translation.should be_approved
        @translation.reviewer.should eql(@reviewer)
      end

      it "should not mark as reviewed a translation not made by a reviewer" do
        @translation.translator = FactoryGirl.create(:user, role: 'translator')
        @translation.copy       = 'foobar'
        @translation.save!
        @translation.approved.should be_nil
      end

      it "should not mark as reviewed a translation whose copy was not changed" do
        @translation.copy = 'foobar'
        @translation.save!
        @translation.approved.should be_nil

        @translation.translator = @reviewer
        @translation.save!
        @translation.approved.should be_nil
      end

      it "should not mark as reviewed a translation subsequently modified by a reviewer" do
        @translation.translator = @reviewer
        @translation.save!
        @translation.approved.should be_nil

        @translation.copy = 'foobar'
        @translation.save!
        @translation.approved.should be_nil
      end

      it "should not mark as reviewed a translation that was de-translated by a reviewer" do
        @translation.copy = 'foobar'
        @translation.save!
        @translation.approved.should be_nil

        @translation.copy       = nil
        @translation.translator = @reviewer
        @translation.save!
        @translation.approved.should be_nil
      end
    end

    context "[translation memory]" do
      it "should update the translation memory when not pre-approved" do
        translation = FactoryGirl.create(:translation, approved: nil)
        TranslationUnit.exact_matches(translation).should be_empty
      end

      it "should update the translation memory when pre-approved" do
        translation = FactoryGirl.create(:translation, approved: true)
        tu          = TranslationUnit.exact_matches(translation).first
        tu.copy.should eql(translation.copy)
        tu.locale.should eql(translation.locale)
      end

      it "should update the translation memory when approved" do
        translation = FactoryGirl.create(:translation, approved: nil)
        translation.update_attribute :approved, true
        tu = TranslationUnit.exact_matches(translation).first
        tu.copy.should eql(translation.copy)
        tu.locale.should eql(translation.locale)
      end

      it "should not update the translation memory when updated but not approved" do
        translation = FactoryGirl.create(:translation, approved: nil)
        translation.update_attribute :translator, FactoryGirl.create(:user)
        TranslationUnit.exact_matches(translation).should be_empty
      end
    end
  end

  context "[validations]" do
    it "should not allow untranslated translations to be approved" do
      trans = FactoryGirl.build(:translation, copy: nil, approved: true)
      trans.should_not be_valid
      trans.errors[:approved].should eql(["cannot be set when translation is pending"])
    end

    it "should not allow untranslated translations to be rejected" do
      trans = FactoryGirl.build(:translation, copy: nil, approved: false)
      trans.should_not be_valid
      trans.errors[:approved].should eql(["cannot be set when translation is pending"])
    end

    it "should allow translations with blank source copy" do
      trans = FactoryGirl.build(:translation, source_copy: "", copy: nil)
      trans.should be_valid
    end
  end
end
