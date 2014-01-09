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
  context "[hooks]" do
    before :all do
      @key = FactoryGirl.create(:key, project: FactoryGirl.create(:project,
                                                                  targeted_rfc5646_locales: {'en' => true, 'de' => true}))
      FactoryGirl.create :translation, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true, key: @key
      @commit      = FactoryGirl.create(:commit, project: @key.project)
      @commit.keys = [@key]
    end

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

    context "[readiness recalculation]" do
      it "should recalculate the readiness of all affected commits when added" do
        FactoryGirl.create :translation, key: @key, rfc5646_locale: 'de', approved: true
        expect(@key.reload).to be_ready
        expect(@commit.reload).to be_ready
      end

      it "should recalculate the readiness of all affected commits when modified" do
        trans = FactoryGirl.create(:translation, key: @key, rfc5646_locale: 'de', approved: true)
        trans.update_attribute :approved, false
        expect(@key.reload).not_to be_ready
        expect(@commit.reload).not_to be_ready
      end
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
      before :all do
        @key      = FactoryGirl.create(:key)
        @reviewer = FactoryGirl.create(:user, role: 'reviewer')
      end
      before(:each) { @translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, reviewer: nil) }

      it "should automatically mark as reviewed translations made by a translator" do
        @translation.translator = @reviewer
        @translation.copy       = 'foobar'
        @translation.save!
        expect(@translation).to be_approved
        expect(@translation.reviewer).to eql(@reviewer)
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

    context "[translation memory]" do
      it "should update the translation memory when not pre-approved" do
        translation = FactoryGirl.create(:translation, approved: nil)
        expect(TranslationUnit.exact_matches(translation)).to be_empty
      end

      it "should update the translation memory when pre-approved" do
        translation = FactoryGirl.create(:translation, approved: true)
        tu          = TranslationUnit.exact_matches(translation).first
        expect(tu.copy).to eql(translation.copy)
        expect(tu.locale).to eql(translation.locale)
      end

      it "should update the translation memory when approved" do
        translation = FactoryGirl.create(:translation, approved: nil)
        translation.update_attribute :approved, true
        tu = TranslationUnit.exact_matches(translation).first
        expect(tu.copy).to eql(translation.copy)
        expect(tu.locale).to eql(translation.locale)
      end

      it "should not update the translation memory when updated but not approved" do
        translation = FactoryGirl.create(:translation, approved: nil)
        translation.update_attribute :translator, FactoryGirl.create(:user)
        expect(TranslationUnit.exact_matches(translation)).to be_empty
      end
    end

    context "[manifest precompilation]" do
      before :all do
        @project = FactoryGirl.create(:project, cache_manifest_formats: %w(rb yaml), cache_localization: true, targeted_rfc5646_locales: {'en' => true, 'fr' => true})
        @key1    = FactoryGirl.create(:key, project: @project)
        @key2    = FactoryGirl.create(:key, project: @project)
        @base1   = FactoryGirl.create(:translation, approved: true, key: @key1)
        @base2   = FactoryGirl.create(:translation, approved: true, key: @key2)

        @commit      = FactoryGirl.create(:commit, project: @project)
        @commit.keys = [@key1, @key2]

        @rb  = Mime::Type.lookup('application/x-ruby')
        @yml = Mime::Type.lookup('text/x-yaml')
      end

      before :each do
        @trans1 = FactoryGirl.create(:translation, approved: true, key: @key1, rfc5646_locale: 'fr')
        trans2  = FactoryGirl.create(:translation, approved: true, key: @key2, rfc5646_locale: 'fr')

        @key1.recalculate_ready!
        @key2.recalculate_ready!
        @commit.recalculate_ready!

        expect(@commit.reload).to be_ready
        expect(Shuttle::Redis.exists(LocalizePrecompiler.new.key(@commit))).to be_true
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @rb))).to be_true
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @yml))).to be_true
      end

      it "should expire cached manifests when the copy of an approved translation is changed and the approval status is unchanged" do
        @trans1.update_attributes copy: "new copy", preserve_reviewed_status: true
        expect(Shuttle::Redis.exists(LocalizePrecompiler.new.key(@commit))).to be_false
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @rb))).to be_false
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @yml))).to be_false
      end

      it "should expire cached manifests when a translation is unapproved" do
        @trans1.update_attributes approved: false
        expect(Shuttle::Redis.exists(LocalizePrecompiler.new.key(@commit))).to be_false
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @rb))).to be_false
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @yml))).to be_false
      end

      it "should not expire cached manifests when some other attribute of an approved translation is changed" do
        @trans1.update_attribute :translator, FactoryGirl.create(:user)
        expect(Shuttle::Redis.exists(LocalizePrecompiler.new.key(@commit))).to be_true
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @rb))).to be_true
        expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(@commit, @yml))).to be_true
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

        trans.copy = "{{hello world}}"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid {android} interpolation"])
      end

      it "should apply the fencers in reverse order" do
        key   = FactoryGirl.create(:key, fencers: %w(Erb Html))
        trans = FactoryGirl.create(:translation, key: key)

        trans.copy = "<<%= foo %>em>baz</<%= foo %>em>"
        expect(trans).to be_valid

        trans.copy = "<<%= foo %>em>baz</<%= foo %>b>"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid <HTML> interpolation"])

        trans.copy = "<<%= foo %>em>baz</<%= foo >em>"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid <%= ERb %> interpolation"])

        trans.copy = "<<%= foo %>em>baz</<%= foo >b>"
        expect(trans).not_to be_valid
        expect(trans.errors[:copy]).to eql(["has an invalid <%= ERb %> interpolation"])
      end
    end
  end
end
