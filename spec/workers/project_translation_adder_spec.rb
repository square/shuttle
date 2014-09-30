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

describe ProjectTranslationAdder do
  describe "#perform" do
    it "calls KeyTranslationAdder for keys that are associated with commits of the project, and calls ProjectTranslationAdderFinisher" do
      project = FactoryGirl.create(:project)
      commit = FactoryGirl.create(:commit, project: project)
      key = FactoryGirl.create(:key, project: project)
      key.commits << commit

      expect(KeyTranslationAdder).to receive(:perform_once).with(key.id).once
      ProjectTranslationAdderFinisher.any_instance.should_receive(:on_success)
      ProjectTranslationAdder.new.perform(project.id)
    end

    it "doesn't call KeyTranslationAdder or ProjectTranslationAdderFinisher, or doesn't create a Sidekiq batch if there are no keys with commits in the project" do
      project = FactoryGirl.create(:project)
      key = FactoryGirl.create(:key, project: project)

      expect(Sidekiq::Batch).to_not receive(:new)
      expect(KeyTranslationAdder).to_not receive(:perform_once)
      ProjectTranslationAdderFinisher.any_instance.stub(:on_success).and_raise("this shouldn't have been called")

      ProjectTranslationAdder.new.perform(project.id)
    end

    it "doesn't call KeyTranslationAdder if key is not associated with a commit" do
      project = FactoryGirl.create(:project)
      expect(KeyTranslationAdder).to_not receive(:perform_once)
      ProjectTranslationAdder.new.perform(project.id)
    end
  end

  describe "#key_ids_with_commits" do
    it "returns the ids of keys associated with at least 1 commit" do
      project = FactoryGirl.create(:project)

      commit1 = FactoryGirl.create(:commit, project: project)
      commit2 = FactoryGirl.create(:commit, project: project)

      key1 = FactoryGirl.create(:key, project: project)
      key2 = FactoryGirl.create(:key, project: project)

      commit1.keys << key1
      commit2.keys << key1

      expect(ProjectTranslationAdder.new.send(:key_ids_with_commits, project)).to eql([key1.id])
    end
  end
end
