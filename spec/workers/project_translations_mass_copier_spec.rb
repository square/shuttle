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

describe ProjectTranslationsMassCopier do
  describe "#perform" do
    before :each do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'en' => true, 'en-XX' => true, 'en-YY' => false, 'es-XX' => false })
      @key = FactoryGirl.create(:key, project: @project, ready: false)
      @en_translation    = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'en', copy: 'test', approved: true)
      @en_xx_translation = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'en-XX', copy: nil, approved: nil)
    end

    it "errors if there is a problem with the inputs such as locales not being in the same language family" do
      expect { ProjectTranslationsMassCopier.new.perform(@project.id, 'en', 'es-XX') }.to raise_error(ArgumentError, "Source and target locales are not in the same language family (their ISO639s do not match)")
    end

    it "should not run KeyTranslationCopier or create a batch if all translations are already done in the target locale" do
      @en_xx_translation.update! copy: "test"
      tmc = ProjectTranslationsMassCopier.new
      expect(tmc).to_not receive(:mass_copier_batch)
      expect(KeyTranslationCopier).to_not receive(:perform_once)
      tmc.perform(@project.id, 'en', 'en-XX')
    end

    it "copies translations, and updates keys & commits readiness states" do
      commit = FactoryGirl.create(:commit, project: @project, ready: false)
      commit.keys << @key.reload
      expect(commit.ready).to be_false
      expect(@key.ready).to be_false
      ProjectTranslationsMassCopier.new.perform(@project.id, 'en', 'en-XX')
      expect(@en_xx_translation.reload.copy).to eql('test')
      expect(commit.reload.ready).to be_true
      expect(@key.reload.ready).to be_true
    end
  end

  describe "#find_locale_errors" do
    before :each do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'en' => true, 'en-XX' => true, 'en-YY' => false, 'es-XX' => false })
    end

    it "returns errors if source and target are the same" do
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, nil, nil)).to eql(["Source and target locales cannot be equal to each other"])
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, '', '')).to eql(["Source and target locales cannot be equal to each other"])
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en-XX', 'en-XX')).to eql(["Source and target locales cannot be equal to each other"])
    end

    context "[invalid locales]" do
      it "returns errors if rfc5646_locales are nil" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, nil, 'en-XX')).to eql(["Invalid source locale"])
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en-XX', nil)).to eql(["Invalid target locale"])
      end

      it "returns errors if rfc5646_locales are empty" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, '', 'en-XX')).to eql(["Invalid source locale"])
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', '')).to eql(["Invalid target locale"])
      end

      it "returns errors if rfc5646_locales don't correspond to real locales" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'fr-fr-fr-fr', 'fr-fr-fr-fr-fr')).to eql(["Invalid source locale", "Invalid target locale"])
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'fr-fr-fr-fr', 'en-XX')).to eql(["Invalid source locale"])
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'fr-fr-fr-fr')).to eql(["Invalid target locale"])
      end
    end

    context "[locales among targeted or base locales]" do
      it "returns errors if source locale is not one of the project's targeted locales or the base locale" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en-ZZ', 'en-XX')).to eql(["Source locale is neither the base locale nor one of the project target locales"])
      end

      it "doesn't return errors if source locale is project's base locale" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
      end

      it "doesn't return errors if source locale is one of the project's targeted locales" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en-YY', 'en-XX')).to be_empty
      end

      it "returns errors if target locale is project's base locale; translations in the base locale should not be updated" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en-XX', 'en')).to eql(["Cannot copy to project base locale"])
      end

      it "returns errors if target locale is not one of the project's targeted locales" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'en-ZZ')).to eql(["Target locale is not one of the project target locales"])
      end

      it "doesn't return errors if target locale is one of the project's targeted locales" do
        expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
      end
    end

    it "returns errors if iso639s of the given locales do not match up" do
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en-XX', 'es-XX')).to eql(["Source and target locales are not in the same language family (their ISO639s do not match)"])
    end

    it "doesn't return errors for translating from en to en-XX" do
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
    end

    it "doesn't return errors for translating from en-XX to en-YY" do
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to be_empty
    end

    it "returns errors if project translation adder is still running" do
      @project.stub(:translations_adder_and_remover_batch_status).and_return(double("batch_status"))
      expect(ProjectTranslationsMassCopier.find_locale_errors(@project, 'en', 'en-XX')).to eql(["Project Translations Adder And Remover batch is still running. Try after it finishes."])
    end
  end

  describe "#key_ids_with_copyable_translations" do
    it "returns ids of keys for which we can copy translations from the the source locale to the target locale" do
      project = FactoryGirl.create(:project)
      # create a copyable key
      key1 = FactoryGirl.create(:key, project: project)
      fr_translation_1    = FactoryGirl.create(:translation, key: key1, rfc5646_locale: 'fr', copy: 'test', approved: true)
      fr_xx_translation_1 = FactoryGirl.create(:translation, key: key1, rfc5646_locale: 'fr-XX', copy: nil, approved: nil)

      # create another copyable key
      key2 = FactoryGirl.create(:key, project: project)
      fr_translation_2    = FactoryGirl.create(:translation, key: key2, rfc5646_locale: 'fr', copy: 'test', approved: true)
      fr_xx_translation_2 = FactoryGirl.create(:translation, key: key2, rfc5646_locale: 'fr-XX', copy: nil, approved: nil)

      # create a not-copyable key because translation in the target locale is already done
      key3 = FactoryGirl.create(:key, project: project)
      fr_translation_3    = FactoryGirl.create(:translation, key: key3, rfc5646_locale: 'fr',    copy: 'test', approved: true)
      fr_xx_translation_3 = FactoryGirl.create(:translation, key: key3, rfc5646_locale: 'fr-XX', copy: 'test', approved: true)

      # create a not-copyable key because translation in the source locale is not approved
      key4 = FactoryGirl.create(:key, project: project)
      fr_translation_4    = FactoryGirl.create(:translation, key: key4, rfc5646_locale: 'fr',    copy: 'test', approved: nil)
      fr_xx_translation_4 = FactoryGirl.create(:translation, key: key4, rfc5646_locale: 'fr-XX', copy: nil,    approved: nil)

      # create a not-copyable key because translation in the source locale does not exist
      key5 = FactoryGirl.create(:key, project: project)
      fr_xx_translation_5 = FactoryGirl.create(:translation, key: key5, rfc5646_locale: 'fr-XX', copy: nil, approved: nil)

      # create a not-copyable key because translation in the target locale does not exist
      key6 = FactoryGirl.create(:key, project: project)
      fr_translation_6 = FactoryGirl.create(:translation, key: key6, rfc5646_locale: 'fr', copy: 'test', approved: true)

      expect(ProjectTranslationsMassCopier.new.key_ids_with_copyable_translations(project, 'fr', 'fr-XX').sort).to eql([key1.id, key2.id].sort)
    end
  end

  describe "#mass_copier_batch" do
    it "returns a batch with the correct description which calls ProjectTranslationsMassCopier::Finisher (& ProjectDescendantsRecalculator) on success" do
      project = FactoryGirl.create(:project)
      batch = ProjectTranslationsMassCopier.new.mass_copier_batch(project.id, 'en', 'en-XX')
      expect(batch).to be_a_kind_of(Sidekiq::Batch)
      expect(batch.description).to eql("Project Translations Mass Copier #{project.id} (en -> en-XX)")
      ProjectTranslationsMassCopier::Finisher.any_instance.should_receive(:on_success).with(anything(), {'project_id' => project.id}).and_call_original
      expect(ProjectDescendantsRecalculator).to receive(:perform_once).with(project.id)
      batch.jobs {}
    end

    it "returns a new batch with a new bid" do
      project = FactoryGirl.create(:project)
      batch = ProjectTranslationsMassCopier.new.mass_copier_batch(project.id, 'en', 'en-XX')
      initial_bid = batch.bid
      batch = ProjectTranslationsMassCopier.new.mass_copier_batch(project.id, 'en', 'en-XX')
      expect(batch.bid).to_not eql(initial_bid)
    end
  end
end

describe ProjectTranslationsMassCopier::Finisher do
  describe "#on_success" do
    it "calls ProjectDescendantsRecalculator with project id" do
      project = FactoryGirl.create(:project)
      expect(ProjectDescendantsRecalculator).to receive(:perform_once).with(project.id)
      ProjectTranslationsMassCopier::Finisher.new.on_success(nil, { 'project_id' => project.id })
    end
  end
end
