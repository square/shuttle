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

describe ProjectDescendantsRecalculator do
  describe "#perform" do
    it "recalculates ready for all Keys of the project" do
      # setup
      project = FactoryGirl.create(:project)
      key1 = FactoryGirl.create(:key, project: project)
      key2 = FactoryGirl.create(:key, project: project)

      project.keys.update_all ready: false

      ProjectDescendantsRecalculator.new.perform(project.id)
      expect(key1.reload).to be_ready
      expect(key2.reload).to be_ready
    end

    it "recalculates ready for all Commits of the project" do
      # setup
      project = FactoryGirl.create(:project)
      commit1 = FactoryGirl.create(:commit, project: project)
      commit2 = FactoryGirl.create(:commit, project: project)

      project.commits.update_all ready: false

      ProjectDescendantsRecalculator.new.perform(project.id)
      expect(commit1.reload).to be_ready
      expect(commit2.reload).to be_ready
    end

    it "recalculates ready for all Articles of the project" do
      # setup
      ArticleImporter.any_instance.stub(:perform) # prevent it from creating keys
      project = FactoryGirl.create(:project)
      article1 = FactoryGirl.create(:article, project: project)
      article2 = FactoryGirl.create(:article, project: project)

      project.articles.update_all ready: false

      ProjectDescendantsRecalculator.new.perform(project.id)
      expect(article1.reload).to be_ready
      expect(article2.reload).to be_ready
    end
  end
end
