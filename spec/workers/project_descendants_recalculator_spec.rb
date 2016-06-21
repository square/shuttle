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

      test_project_descendants_recalculator(project)

      expect(key1.reload).to be_ready
      expect(key2.reload).to be_ready
    end

    it "recalculates ready for all Commits of the project" do
      # setup
      project = FactoryGirl.create(:project)
      commit1 = FactoryGirl.create(:commit, project: project)
      commit2 = FactoryGirl.create(:commit, project: project)
      project.commits.update_all ready: false

      test_project_descendants_recalculator(project)

      expect(commit1.reload).to be_ready
      expect(commit2.reload).to be_ready
    end

    it "recalculates ready for all Articles of the project" do
      # setup
      project, article1, article2 = nil, nil, nil

      # https://github.com/mperham/sidekiq/wiki/Testing
      Sidekiq::Testing.fake! do
        project = FactoryGirl.create(:project)
        article1 = FactoryGirl.create(:article, project: project)
        article2 = FactoryGirl.create(:article, project: project)
        project.articles.update_all ready: false
        test_project_descendants_recalculator(project)
      end
      expect(article1.reload).to be_ready
      expect(article2.reload).to be_ready
    end
  end

  # We need to stub ArticleImporter to prevent it from creating keys at some cases.
  # However, allow_any_instance_of(ArticleImporter).to receive(:perform) will also affect other tests for some reason.
  # TODO refactor once you have a better idea

  def test_project_descendants_recalculator(project)
    Key.batch_recalculate_ready!(project)

    project.commits.find_each do |commit|
      CommitRecalculator.new.perform(commit.id)
    end

    project.articles.find_each do |article|
      ArticleRecalculator.new.perform(article.id)
    end
  end
end
