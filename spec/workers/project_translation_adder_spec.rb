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
    it "calls KeyTranslationAdder for keys that are associated with commits of the project, and calls CommitStatsRecalculator for all commits of the project" do
      project = FactoryGirl.create(:project, repository_url: "")
      key_group = FactoryGirl.create(:key_group, project: project, source_copy: "test")
      commit = FactoryGirl.create(:commit, project: project)
      key = FactoryGirl.create(:key, project: project)
      key.commits << commit

      expect(key_group.reload.keys.length).to eql(1) # make sure there is 1 key in the database
      expect(key_group.keys.first.key_group).to_not be_nil

      expect(KeyTranslationAdder).to receive(:perform_once).with(key.id, anything()).once
      expect(KeyTranslationAdder).to_not receive(:perform_once).with(key_group.keys.first.id, anything())
      expect(CommitStatsRecalculator).to receive(:perform_once).with(commit.id).once

      ProjectTranslationAdder.perform_async(project.id)
    end

    it "doesn't call KeyTranslationAdder if key is not associated with a commit" do
      project = FactoryGirl.create(:project, repository_url: "")
      key_group = FactoryGirl.create(:key_group, project: project, source_copy: "test")

      expect(key_group.reload.keys.length).to eql(1) # make sure there is 1 key in the database

      expect(KeyTranslationAdder).to_not receive(:perform_once)

      ProjectTranslationAdder.perform_async(project.id)
    end
  end
end
