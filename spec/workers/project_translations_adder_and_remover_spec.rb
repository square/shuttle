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

describe ProjectTranslationsAdderAndRemover do
  describe "#perform" do
    it "calls KeyTranslationAdderAndRemover for project's keys and ProjectTranslationsAdderAndRemover::Finisher" do
      project = FactoryGirl.create(:project)
      key1 = FactoryGirl.create(:key, project: project)
      key2 = FactoryGirl.create(:key, project: project)

      expect(KeyTranslationAdderAndRemover).to receive(:perform_once).with(key1.id).once
      expect(KeyTranslationAdderAndRemover).to receive(:perform_once).with(key2.id).once
      ProjectTranslationsAdderAndRemover::Finisher.any_instance.should_receive(:on_success)
      ProjectTranslationsAdderAndRemover.new.perform(project.id)
    end

    it "doesn't call KeyTranslationAdderAndRemover if project doesn't have any keys" do
      project = FactoryGirl.create(:project)
      expect(KeyTranslationAdderAndRemover).to_not receive(:perform_once)
      ProjectTranslationsAdderAndRemover.new.perform(project.id)
    end
  end
end

describe ProjectTranslationsAdderAndRemover::Finisher do
  describe "#on_success" do
    it "runs ProjectTranslationsAdderAndRemover::Finisher; sets translations_adder_and_remover_batch_id to nil" do
      @project = FactoryGirl.create(:project, translations_adder_and_remover_batch_id: "11111111")
      expect(ProjectDescendantsRecalculator).to receive(:perform_once).with(@project.id)
      ProjectTranslationsAdderAndRemover::Finisher.new.on_success(nil, { 'project_id' => @project.id })
      expect(@project.reload.translations_adder_and_remover_batch_id).to be_nil
    end
  end
end
