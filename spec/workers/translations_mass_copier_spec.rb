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

describe TranslationsMassCopier do
  describe "#perform" do
    before :each do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'en' => true, 'en-XX' => true, 'en-YY' => false, 'es-XX' => false })
      @key = FactoryGirl.create(:key, project: @project, ready: false)
      @en_translation    = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'en', copy: 'test', approved: true, skip_readiness_hooks: true)
      @en_xx_translation = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'en-XX', copy: nil, approved: nil, skip_readiness_hooks: true)
    end

    it "copies translation.copy from the given source locale to given target locale" do
      TranslationsMassCopier.new.perform(@project.id, 'en', 'en-XX')
      expect(@en_xx_translation.reload.copy).to eql('test')
    end

    it "sets approved state to true" do
      TranslationsMassCopier.new.perform(@project.id, 'en', 'en-XX')
      expect(@en_xx_translation.reload.approved).to be_true
    end

    it "updates keys and commits readiness states" do
      commit = FactoryGirl.create(:commit, project: @project, ready: false)
      commit.keys << @key.reload
      expect(commit.ready).to be_false
      expect(@key.ready).to be_false
      TranslationsMassCopier.new.perform(@project.id, 'en', 'en-XX')
      expect(@en_xx_translation.reload.copy).to eql('test')
      expect(commit.reload.ready).to be_true
      expect(@key.reload.ready).to be_true
    end

    it "errors if there is a problem with the inputs such as locales not being in the same language family" do
      expect { TranslationsMassCopier.new.perform(@project.id, 'en', 'es-XX') }.to raise_error(ArgumentError, "Source and target locales are not in the same language family (their ISO639s do not match)")
    end

    it "doesn't copy from not-approved Translation" do
      FactoryGirl.create(:translation, key: @key, source_rfc5646_locale: 'en', rfc5646_locale: 'en-YY', copy: 'test', approved: nil)
      TranslationsMassCopier.new.perform(@project.id, 'en-YY', 'en-XX')
      expect(@en_xx_translation.reload.copy).to be_nil
      expect(@en_xx_translation.approved).to be_nil
    end

    it "doesn't copy to translated Translation" do
      @en_xx_translation.update! copy: 'helloworld', approved: nil
      TranslationsMassCopier.new.perform(@project.id, 'en', 'en-XX')
      expect(@en_xx_translation.reload.copy).to eql('helloworld')
      expect(@en_xx_translation.approved).to be_nil
    end

    it "doesn't copy to base Translation" do
      @en_xx_translation.update! copy: 'helloworld', approved: true
      expect { TranslationsMassCopier.new.perform(@project.id, 'en-XX', 'en') }.to raise_error
      expect(@en_translation.reload.copy).to eql("test")
      expect(@en_translation.approved).to be_true
    end

    it "ignores translations in other source locales than the project" do
      FactoryGirl.create(:translation, key: @key, source_rfc5646_locale: 'en-ZZ', rfc5646_locale: 'en-YY', copy: 'test', approved: true)
      TranslationsMassCopier.new.perform(@project.id, 'en-YY', 'en-XX')
      expect(@en_xx_translation.reload.copy).to be_nil
      expect(@en_xx_translation.approved).to be_nil
    end

    it "will not update the translation if it cannot find the from_translation (maybe that key was blacklisted in that source locale)" do
      TranslationsMassCopier.new.perform(@project.id, 'en-YY', 'en-XX')
      expect(@en_xx_translation.reload.copy).to be_nil
      expect(@en_xx_translation.approved).to be_nil
    end
  end

  describe "#find_locale_errors" do
    before :each do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'en' => true, 'en-XX' => true, 'en-YY' => false, 'es-XX' => false })
    end

    it "returns errors if source and target are the same" do
      expect(TranslationsMassCopier.find_locale_errors(@project, nil, nil)).to eql(["Source and target locales cannot be equal to each other"])
      expect(TranslationsMassCopier.find_locale_errors(@project, '', '')).to eql(["Source and target locales cannot be equal to each other"])
      expect(TranslationsMassCopier.find_locale_errors(@project, 'en-XX', 'en-XX')).to eql(["Source and target locales cannot be equal to each other"])
    end

    context "[invalid locales]" do
      it "returns errors if rfc5646_locales are nil" do
        expect(TranslationsMassCopier.find_locale_errors(@project, nil, 'en-XX')).to eql(["Invalid source locale"])
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en-XX', nil)).to eql(["Invalid target locale"])
      end

      it "returns errors if rfc5646_locales are empty" do
        expect(TranslationsMassCopier.find_locale_errors(@project, '', 'en-XX')).to eql(["Invalid source locale"])
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en', '')).to eql(["Invalid target locale"])
      end

      it "returns errors if rfc5646_locales don't correspond to real locales" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'fr-fr-fr-fr', 'fr-fr-fr-fr-fr')).to eql(["Invalid source locale", "Invalid target locale"])
        expect(TranslationsMassCopier.find_locale_errors(@project, 'fr-fr-fr-fr', 'en-XX')).to eql(["Invalid source locale"])
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'fr-fr-fr-fr')).to eql(["Invalid target locale"])
      end
    end

    context "[locales among targeted or base locales]" do
      it "returns errors if source locale is not one of the project's targeted locales or the base locale" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en-ZZ', 'en-XX')).to eql(["Source locale is neither the base locale nor one of the project target locales"])
      end

      it "doesn't return errors if source locale is project's base locale" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
      end

      it "doesn't return errors if source locale is one of the project's targeted locales" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en-YY', 'en-XX')).to be_empty
      end

      it "returns errors if target locale is project's base locale; translations in the base locale should not be updated" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en-XX', 'en')).to eql(["Cannot copy to project base locale"])
      end

      it "returns errors if target locale is not one of the project's targeted locales" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'en-ZZ')).to eql(["Target locale is not one of the project target locales"])
      end

      it "doesn't return errors if target locale is one of the project's targeted locales" do
        expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
      end
    end

    it "returns errors if iso639s of the given locales do not match up" do
      expect(TranslationsMassCopier.find_locale_errors(@project, 'en-XX', 'es-XX')).to eql(["Source and target locales are not in the same language family (their ISO639s do not match)"])
    end

    it "doesn't return errors for translating from en to en-XX" do
      expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
    end

    it "doesn't return errors for translating from en-XX to en-YY" do
      expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
    end

    it "returns errors if project translation adder is still running" do
      @project.stub(:translation_adder_batch_status).and_return(double("batch_status"))
      expect(TranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to eql(["Project Translation Adder batch is still running. Try after it finishes."])
    end
  end
end
