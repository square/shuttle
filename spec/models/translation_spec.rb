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

describe Translation do
  context "[scopes]" do
    describe "#not_approved" do
      it "returns rejected (approved = false) and not reviewed (approved == nil) translations" do
        FactoryGirl.create :translation, approved: true, copy: "fake"
        t2 = FactoryGirl.create :translation, approved: false, copy: "fake"
        t3 = FactoryGirl.create :translation, approved: nil
        expect(Translation.not_approved.to_a).to eql([t2, t3])
      end
    end

    describe "#not_translated" do
      it "returns only not-translated translations" do
        t1 = FactoryGirl.create :translation, copy: nil
        t2 = FactoryGirl.create :translation, copy: nil
        FactoryGirl.create :translation, approved: true,  copy: "fake"
        FactoryGirl.create :translation, approved: false, copy: "fake"
        FactoryGirl.create :translation, approved: nil,   copy: "fake"
        expect(Translation.not_translated.to_a).to eql([t1, t2])
      end
    end
  end

  context "[hooks]" do
    before :each do
      @key = FactoryGirl.create(:key, project: FactoryGirl.create(:project,
                                                                  targeted_rfc5646_locales: {'en' => true, 'de' => true}))
      FactoryGirl.create :translation, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true, key: @key
      @commit      = FactoryGirl.create(:commit, project: @key.project)
      @commit.keys = [@key]
    end

    context "[resetting reviewed state]" do
      it "should reset the reviewed state when the copy is changed" do
        trans = FactoryGirl.create(:translation, approved: true, reviewer: FactoryGirl.create(:user))
        trans.update_attribute :copy, "New copy"
        expect(trans.reviewer_id).to be_nil
        expect(trans.approved).to be_nil
      end

      it "should not reset the reviewed state when the copy is not changed" do
        trans = FactoryGirl.create(:translation, approved: true, reviewer: FactoryGirl.create(:user))
        trans.update_attribute :translator, FactoryGirl.create(:user)
        expect(trans.reviewer_id).not_to be_nil
        expect(trans.approved).to eql(true)
      end

      it "should not reset the reviewed state if the reviewed state is changed along with the copy" do
        trans = FactoryGirl.create(:translation, approved: false, reviewer: FactoryGirl.create(:user))
        trans.update_attributes(copy: "New copy", approved: true)
        expect(trans.reviewer_id).not_to be_nil
        expect(trans.approved).to eql(true)
      end
    end

    it "should set translated to true upon translation" do
      trans = FactoryGirl.create(:translation, copy: nil)
      expect(trans).not_to be_translated
      trans.update_attribute :copy, "foo"
      expect(trans).to be_translated
    end

    context "[automatically setting reviewed]" do
      before :each do
        @key      = FactoryGirl.create(:key)
        @reviewer = FactoryGirl.create(:user, role: 'reviewer')
        @translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, reviewer: nil)
      end

      it "should not mark as reviewed a translation not made by a reviewer" do
        @translation.translator = FactoryGirl.create(:user, role: 'translator')
        @translation.copy       = 'foobar'
        @translation.save!
        expect(@translation.approved).to be_nil
      end

      it "should not mark as reviewed a translation whose copy was not changed" do
        @translation.copy = 'foobar'
        @translation.save!
        expect(@translation.approved).to be_nil

        @translation.translator = @reviewer
        @translation.save!
        expect(@translation.approved).to be_nil
      end

      it "should not mark as reviewed a translation subsequently modified by a reviewer" do
        @translation.translator = @reviewer
        @translation.save!
        expect(@translation.approved).to be_nil

        @translation.copy = 'foobar'
        @translation.save!
        expect(@translation.approved).to be_nil
      end

      it "should not mark as reviewed a translation that was de-translated by a reviewer" do
        @translation.copy = 'foobar'
        @translation.save!
        expect(@translation.approved).to be_nil

        @translation.copy       = nil
        @translation.translator = @reviewer
        @translation.save!
        expect(@translation.approved).to be_nil
      end
    end
  end

  context "[validations]" do
    it "should not allow untranslated translations to be approved" do
      trans = FactoryGirl.build(:translation, copy: nil, approved: true)
      expect(trans).not_to be_valid
      expect(trans.errors[:approved]).to eql(["cannot be set when translation is pending"])
    end

    it "should not allow untranslated translations to be rejected" do
      trans = FactoryGirl.build(:translation, copy: nil, approved: false)
      expect(trans).not_to be_valid
      expect(trans.errors[:approved]).to eql(["cannot be set when translation is pending"])
    end

    it "should allow translations with blank source copy" do
      trans = FactoryGirl.build(:translation, source_copy: "", copy: nil)
      expect(trans).to be_valid
    end

    context "[fencing]" do
      it "should add an error if the interpolation is invalid" do
        key   = FactoryGirl.create(:key, fencers: %w(Android))
        trans = FactoryGirl.create(:translation, key: key)

        trans.source_copy = trans.copy = "{{hello world}}"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid {android} interpolation"])
      end

      it "should only perform validations on the first fencer" do
        key   = FactoryGirl.create(:key, fencers: %w(Erb Html))
        trans = FactoryGirl.create(:translation, key: key)

        trans.source_copy = trans.copy = "<<%= foo %>em>baz</<%= foo %>em>"
        expect(trans).to be_valid

        # Only checks the first validation 
        trans.source_copy = trans.copy = "<<%= foo %>em>baz</<%= foo %>b>"
        expect(trans).to be_valid

        trans.source_copy = trans.copy = "<<%= foo %>em>baz</<%= foo >em>"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid <%= ERb %> interpolation"])

        trans.source_copy = trans.copy = "<<%= foo %>em>baz</<%= foo >b>"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid <%= ERb %> interpolation"])
      end
    end

    context "[fences_must_match]" do
      let(:key) { FactoryGirl.create(:key, fencers: %w(Mustache Html Printf)) }
      let(:translation) { FactoryGirl.create(:translation, key: key, source_copy: "test {{hello}} {{hello}} <strong>hi</strong> {{howareyou}}", copy: nil, approved: nil) }

      it "should not validate fences if the locale is a pseudo locale" do
        translation = FactoryGirl.build(:translation, key: key, source_copy: "Refund %@", copy: "gd4!&!^~*", source_rfc5646_locale: 'en', rfc5646_locale: 'en-pseudo', approved: true, preserve_reviewed_status: true)
        expect(translation).to be_valid
      end

      it "should allow creating base translations" do
        translation = FactoryGirl.build(:translation, key: key, source_copy: "Refund %@", copy: "Refund %@", approved: true, source_rfc5646_locale: 'en', rfc5646_locale: 'en', preserve_reviewed_status: true)
        expect(translation).to be_valid
      end

      it "should allow copy = nil even if source_copy has fences" do
        translation = FactoryGirl.build(:translation, key: key, source_copy: "{{hello}}", copy: nil)
        expect(translation).to be_valid
      end

      it "should not allow copy to have missing fences even if approved = nil" do
        translation.update copy: "test"
        expect(translation.errors.messages).to eql(copy: ["fences do not match the source copy fences"])
      end

      it "should allow copy and source_copy to have the same fences" do
        translation.update copy: "test {{hello}} {{hello}} <strong>hi</strong> {{howareyou}}"
        expect(translation).to be_valid
      end

      it "should allow copy and source_copy to have the same fences, even if fences are in a different order" do
        translation.update copy: "{{howareyou}}<strong>hi</strong> test {{hello}} {{hello}}"
        expect(translation).to be_valid
      end

      it "should not allow adding a fence that doesn't exist in the source_copy" do
        translation.update copy: "test {{hello}} {{thisisnew}} {{hello}} <strong>hi</strong> {{howareyou}}"
        expect(translation.errors.messages).to eql(copy: ["fences do not match the source copy fences"])
      end

      it "should not allow removing a fence that exist in the source_copy" do
        translation.update copy: "test {{hello}} {{hello}} <strong>hi</strong>"
        expect(translation.errors.messages).to eql(copy: ["fences do not match the source copy fences"])
      end

      it "should allow using a fence less number of times than used in the source_copy, as long as it's used only once" do
        translation.update copy: "test {{hello}} <strong>hi</strong> {{howareyou}}"
        expect(translation).to be_valid
      end

      it "should allow using a fence more number of times than used in the source_copy" do
        translation.update copy: "{{howareyou}} test {{hello}} {{hello}} {{hello}} <strong>hi</strong> {{howareyou}} {{howareyou}}"
        expect(translation).to be_valid
      end

      it "should handle japanese characters which may be problematic" do
        # This is a special case which was encountered during manual testing
        translation = FactoryGirl.build(:translation, key: key, source_copy: "<span class='sales-trends'>", copy: "べ<span class='sales-trends'>")
        expect(translation).to be_valid
      end

      it "should allow repeating tokens for iOS even if the source copy does not specify order" do
        translation = FactoryGirl.build(:translation, key: key, source_copy: "Refund %2$@ %1$@ %2$@", copy: "Refund %@ %@")
        expect(translation).to be_valid
      end
    end
  end

  describe "#potential_commit" do
    it "returns the first SHA found in Shuttle for this translation's key" do
      project = FactoryGirl.create(:project)
      key = FactoryGirl.create(:key, project: project)
      translation = FactoryGirl.create(:translation, key: key)

      commit1 = FactoryGirl.create(:commit, project: project)
      commit2 = FactoryGirl.create(:commit, project: project)
      commit1.keys = commit2.keys = [key]

      expect(translation.potential_commit).to eql(commit1)
    end

    it "returns nil if it cannot find any commits linked to this translation's key" do
      expect(FactoryGirl.create(:translation).potential_commit).to be_nil
    end
  end

  describe "#batch_refresh_elastic_search" do
    it "refreshes the ElasticSearch index (section_active field in this test) of Article's Translations" do
      Article.any_instance.stub(:import!) # prevent auto import
      reset_elastic_search

      article = FactoryGirl.create(:article)
      section = FactoryGirl.create(:section, article: article, active: true)
      key = FactoryGirl.create(:key, section: section, index_in_section: 0, project: article.project)
      translation = FactoryGirl.create(:translation, key: key)

      regenerate_elastic_search_indexes
      sleep(2)

      expect(Translation.search(load: true) { filter :term, section_active: true }.first).to eql(translation)
      expect(Translation.search(load: true) { filter :term, section_active: false }.first).to be_nil

      section.update! active: false
      Translation.batch_refresh_elastic_search(article)
      sleep(2)

      expect(Translation.search(load: true) { filter :term, section_active: true }.first).to be_nil
      expect(Translation.search(load: true) { filter :term, section_active: false }.first).to eql(translation)
    end
  end
end
