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

# More specs for TranslationUpdateMediator are in translations_controller_specs#update as integration specs.

require 'spec_helper'

describe TranslationUpdateMediator do
  let(:translator) { FactoryGirl.create(:user, :translator) }
  let(:reviewer) { FactoryGirl.create(:user, :reviewer) }

  describe "#update!" do
    before :each do
      @params = ActionController::Parameters.new(translation: { copy: "test copy", notes: "test note" })

      project = FactoryGirl.create(:project, targeted_rfc5646_locales: { 'fr' => true, 'fr-CA' =>true, 'fr-FR' => true } )
      @key = FactoryGirl.create(:key, ready: false, project: project)
      @fr_translation    = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr')
      expect(@key.reload).to_not be_ready
    end

    it "updates a single translation's 'copy' and 'notes' fields; doesn't approve translation if translator is not a reviewer; key doesn't become ready" do
      TranslationUpdateMediator.new(@fr_translation, translator, @params).update!
      expect(@fr_translation.reload.copy).to eql("test copy")
      expect(@fr_translation.notes).to eql("test note")
      expect(@fr_translation.translator).to eql(translator)
      expect(@fr_translation.approved).to be_nil
      expect(@fr_translation.reviewer).to be_nil
      expect(@key.reload).to_not be_ready
    end

    it "updates a single translation; approve translation if translator is a reviewer; key becomes ready" do
      TranslationUpdateMediator.new(@fr_translation, reviewer, @params).update!
      expect(@fr_translation.copy).to eql("test copy")
      expect(@fr_translation.translator).to eql(reviewer)
      expect(@fr_translation.approved).to be_true
      expect(@fr_translation.reviewer).to eql(reviewer)
      expect(@key.reload).to be_ready
    end

    context "[update multiple]" do
      before :each do
        FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA')
        FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-FR')

        @fr_CA_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr-CA')
        @fr_FR_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr-FR')
      end

      it "updates the primary translation and 2 associated translations that user specified; sets key readiness to true if all translations are approved" do
        params = ActionController::Parameters.new( translation: { copy: "test" }, copyToLocales: %w(fr-CA fr-FR) )
        TranslationUpdateMediator.new(@fr_translation, reviewer, params).update!
        expect(@fr_translation.reload.copy).to eql("test")
        expect(@fr_translation.translator).to eql(reviewer)
        expect(@fr_CA_translation.reload.copy).to eql("test")
        expect(@fr_CA_translation.translator).to eql(reviewer)
        expect(@fr_FR_translation.reload.copy).to eql("test")
        expect(@fr_FR_translation.translator).to eql(reviewer)
        expect(@key.reload.ready).to be_true
      end

      it "recalculates readiness of the key only once even if it's updating multiple translations" do
        params = ActionController::Parameters.new( translation: { copy: "test" }, copyToLocales: %w(fr-CA fr-FR) )
        expect_any_instance_of(Key).to receive(:recalculate_ready!).once.and_call_original
        TranslationUpdateMediator.new(@fr_translation, reviewer, params).update!
        expect(@key.reload.ready).to be_true
      end

      it "doesn't update any of the requested translations because one of the translations don't exist" do
        FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-XX')
        params = ActionController::Parameters.new( translation: { copy: "test" }, copyToLocales: %w(fr-CA fr-FR fr-XX) )
        mediator = TranslationUpdateMediator.new(@fr_translation, reviewer, params)
        mediator.update!
        expect(@fr_translation.reload.copy).to be_nil
        expect(@fr_CA_translation.reload.copy).to be_nil
        expect(@fr_FR_translation.reload.copy).to be_nil
        expect(mediator.errors).to eql(["Cannot update translation in locale fr-XX"])
      end

      it "doesn't update any of the requested translations because there is a problem with one of them" do
        @fr_translation.errors.add(:fake, 'error')
        @fr_translation.stub!(:save!).and_raise(ActiveRecord::RecordInvalid, @fr_translation) # should cause save! to fail

        params = ActionController::Parameters.new( translation: { copy: "test" }, copyToLocales: %w(fr-CA fr-FR) )
        mediator = TranslationUpdateMediator.new(@fr_translation, reviewer, params)
        mediator.update!
        expect(@fr_translation.reload.copy).to be_nil
        expect(@fr_CA_translation.reload.copy).to be_nil
        expect(@fr_FR_translation.reload.copy).to be_nil
        expect(mediator.errors).to eql(["(fr): Fake error"])
      end
    end
  end

  describe "#multi_updateable_translations_to_locale_associations_hash" do
    it "returns a hash of translations that can be updated with the same copy as the primary translation will be
          updated with, and the LocaleAssociations that connect these translations with the primary translation" do
      la1 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA')
      la2 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-FR')
      la3 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-XX')
      la4 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-YY')
      la5 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr-CA', target_rfc5646_locale: 'fr')

      project = FactoryGirl.create(:project, targeted_rfc5646_locales: { 'fr' => true, 'fr-CA' => true, 'fr-FR' => false, 'fr-XX' => true })
      key = FactoryGirl.create(:key, project: project)
      translation1 = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr')
      translation2 = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr-CA')
      translation3 = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr-FR')
      expect(TranslationUpdateMediator.multi_updateable_translations_to_locale_associations_hash(translation1)).to eql(translation2 => la1, translation3 => la2)
    end

    it "doesn't consider base translation as a multi updateable translation" do
      la1 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'en-XX', target_rfc5646_locale: 'en')
      la2 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'en-XX', target_rfc5646_locale: 'en-YY')

      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'en-XX' => true, 'en-YY' => true })
      key = FactoryGirl.create(:key, project: project)
      translation1 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en-XX')
      translation2 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      translation3 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en-YY')
      expect(TranslationUpdateMediator.multi_updateable_translations_to_locale_associations_hash(translation1)).to eql(translation3 => la2)
    end
  end

  describe "#translations_that_should_be_multi_updated" do
    before :each do
      FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA')
      FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-FR')
      @key = FactoryGirl.create(:key)
      @fr_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr')
    end

    it "returns the Translation objects corresponding to the user provided copyToLocales param; doesn't add an error if all are valid" do
      fr_CA_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr-CA')
      fr_FR_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr-FR')
      mediator = TranslationUpdateMediator.new(@fr_translation, translator, ActionController::Parameters.new( copyToLocales: %w(fr-CA fr-FR) ))
      expect(mediator.send(:translations_that_should_be_multi_updated)).to eql([fr_CA_translation, fr_FR_translation])
      expect(mediator.success?).to be_true
    end

    it "adds an error to the mediator if one of the locales user wanted to copy to is not valid because there is no LocaleAssociation to that locales" do
      fr_XX_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr-XX')
      mediator = TranslationUpdateMediator.new(@fr_translation, translator, ActionController::Parameters.new( copyToLocales: %w(fr-XX)))
      mediator.send(:translations_that_should_be_multi_updated)
      expect(mediator.success?).to be_false
      expect(mediator.errors).to eql(["Cannot update translation in locale fr-XX"])
    end

    it "adds an error to the mediator if one of the locales user wanted to copy to is not valid because there is no Translation in one of those locales" do
      fr_CA_translation = FactoryGirl.create(:translation, key: @key, copy: nil, translator: nil, rfc5646_locale: 'fr-CA')
      mediator = TranslationUpdateMediator.new(@fr_translation, translator, ActionController::Parameters.new( copyToLocales: %w(fr-CA fr-FR)))
      mediator.send(:translations_that_should_be_multi_updated)
      expect(mediator.success?).to be_false
      expect(mediator.errors).to eql(["Cannot update translation in locale fr-FR"])
    end
  end

  describe "#update_single_translation!" do
    let(:translation) { FactoryGirl.create(:translation, copy: nil, translator: nil) }

    it "updates a translation with the given copy and notes, sets its translator" do
      params = ActionController::Parameters.new(translation: { copy: "test copy", notes: "test note" })
      mediator = TranslationUpdateMediator.new(translation, translator, params)
      mediator.send(:update_single_translation!, translation)
      expect(translation.copy).to eql("test copy")
      expect(translation.notes).to eql("test note")
      expect(translation.translator).to eql(translator)
    end

    it "untranslates an approved translation if copy is blank and blank_string was not specified" do
      translation.update copy: "test", approved: true, reviewer: reviewer, translator: translator
      expect(translation.approved).to be_true

      params = ActionController::Parameters.new(translation: { copy: "" })
      mediator = TranslationUpdateMediator.new(translation, translator, params)
      mediator.send(:update_single_translation!, translation)
      expect(translation.copy).to be_nil
      expect(translation.approved).to be_nil
      expect(translation.translator).to be_nil
      expect(translation.reviewer).to be_nil
    end

    it "updates with empty string if copy is empty and blank_string is specified" do
      params = ActionController::Parameters.new(translation: { copy: "" }, blank_string: "1" )
      mediator = TranslationUpdateMediator.new(translation, translator, params)
      mediator.send(:update_single_translation!, translation)
      expect(translation.copy).to eql("")
      expect(translation.translated).to be_true
      expect(translation.translator).to eql(translator)
    end

    it "raises an ActiveRecord::RecordInvalid error if translation couldn't be saved" do
      translation.source_rfc5646_locale = nil # should cause save! to fail
      params = ActionController::Parameters.new(translation: { copy: "test" } )
      mediator = TranslationUpdateMediator.new(translation, translator, params)
      expect { mediator.send(:update_single_translation!, translation) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context "[role=translator]" do
      it "updates translation but doesn't approve it" do
        params = ActionController::Parameters.new(translation: { copy: "test" } )
        mediator = TranslationUpdateMediator.new(translation, translator, params)
        mediator.send(:update_single_translation!, translation)
        expect(translation.copy).to eql("test")
        expect(translation.translated).to be_true
        expect(translation.translator).to eql(translator)
        expect(translation.approved).to be_nil
        expect(translation.reviewer).to be_nil
      end

      it "unapproves translation on update if copy changes" do
        translation.update copy: "test", approved: true, reviewer: reviewer, translator: reviewer
        expect(translation.approved).to be_true

        params = ActionController::Parameters.new(translation: { copy: "changed" })
        mediator = TranslationUpdateMediator.new(translation, translator, params)
        mediator.send(:update_single_translation!, translation)
        expect(translation.copy).to eql("changed")
        expect(translation.approved).to be_nil
        expect(translation.translator).to eql(translator)
        expect(translation.reviewer).to be_nil
      end
    end

    context "[role=reviewer]" do
      it "sets translator, reviewer and approves a translation" do
        params = ActionController::Parameters.new(translation: { copy: "test" })
        mediator = TranslationUpdateMediator.new(translation, reviewer, params)
        mediator.send(:update_single_translation!, translation)
        expect(translation.approved).to be_true
        expect(translation.translator).to eql(reviewer)
        expect(translation.reviewer).to eql(reviewer)
      end

      it "approves a translation without changing the translator if the copy didn't change" do
        translation.update copy: "test", translator: translator

        params = ActionController::Parameters.new(translation: { copy: "test" })
        mediator = TranslationUpdateMediator.new(translation, reviewer, params)
        mediator.send(:update_single_translation!, translation)
        expect(translation.approved).to be_true
        expect(translation.translator).to eql(translator)
        expect(translation.reviewer).to eql(reviewer)
      end

      it "saves notes field without approving an empty translation" do
        params = ActionController::Parameters.new(translation: { notes: "test notes" })
        mediator = TranslationUpdateMediator.new(translation, reviewer, params)
        mediator.send(:update_single_translation!, translation)
        expect(translation.notes).to eql("test notes")
        expect(translation.approved).to be_nil
        expect(translation.translator).to be_nil
        expect(translation.reviewer).to be_nil
      end
    end
  end

  describe "#untranslate" do
    it "clears copy, translator, approved and reviewer fields" do
      translation = FactoryGirl.build(:translation, copy: "Test", approved: true, reviewer: reviewer, translator: reviewer)
      mediator = TranslationUpdateMediator.new(translation, reviewer, ActionController::Parameters.new)
      mediator.send(:untranslate, translation)

      expect(translation.copy).to be_nil
      expect(translation.approved).to be_nil
      expect(translation.translator).to be_nil
      expect(translation.reviewer).to be_nil
    end
  end
end
