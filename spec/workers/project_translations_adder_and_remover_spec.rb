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

require 'rails_helper'

RSpec.describe ProjectTranslationsAdderAndRemover do
  # in test environment, sidekiq doesn't run batch callbacks. If we add middleware to enable callbacks
  # in test environment, we should this test back.
  skip "#perform" do
    it "calls KeyTranslationAdderAndRemover for project's keys and ProjectTranslationsAdderAndRemover::Finisher" do
      project = FactoryBot.create(:project)
      key1 = FactoryBot.create(:key, project: project)
      key2 = FactoryBot.create(:key, project: project)

      expect(KeyTranslationAdderAndRemover).to receive(:perform_once).with(key1.id).once
      expect(KeyTranslationAdderAndRemover).to receive(:perform_once).with(key2.id).once
      expect_any_instance_of(ProjectTranslationsAdderAndRemover::Finisher).to receive(:on_success)
      ProjectTranslationsAdderAndRemover.new.perform(project.id)
    end

    it "doesn't call KeyTranslationAdderAndRemover if project doesn't have any keys" do
      project = FactoryBot.create(:project)
      expect(KeyTranslationAdderAndRemover).to_not receive(:perform_once)
      ProjectTranslationsAdderAndRemover.new.perform(project.id)
    end
  end
end

RSpec.describe ProjectTranslationsAdderAndRemover::Finisher do
  describe "#on_success" do
    it "runs ProjectTranslationsAdderAndRemover::Finisher; sets translations_adder_and_remover_batch_id to nil" do
      @project = FactoryBot.create(:project, translations_adder_and_remover_batch_id: "11111111")
      expect(ProjectDescendantsRecalculator).to receive(:perform_once).with(@project.id)
      ProjectTranslationsAdderAndRemover::Finisher.new.on_success(nil, { 'project_id' => @project.id })
      expect(@project.reload.translations_adder_and_remover_batch_id).to be_nil
    end
  end
end
