# Copyright 2016 Square Inc.
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

RSpec.describe CommitsCleaner do
  before :each do
    allow(StashWebhookHelper).to receive_message_chain(:new, :ping).and_return(nil)
    @commits_cleaner = CommitsCleaner.new

    @project = FactoryBot.create(:project, :light)
    allow(@project).to receive(:repo).and_return(nil)
  end

  describe "#destroy_dangling_commits" do
    before :each do
      allow_any_instance_of(Commit).to receive(:commit).and_raise(Rugged::OdbError)
    end

    it "should destory all commits" do
      FactoryBot.create_list :commit, 3, project: @project
      regenerate_elastic_search_indexes

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_dangling_commits
      expect(@project.commits.count).to eq(0)
    end

    it "should not destory any ready commits" do
      FactoryBot.create_list :commit, 3, project: @project, ready: true

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_dangling_commits
      expect(@project.commits.count).to eq(3)
    end

    it "should not destory any commits in not git project" do
      not_git_project = FactoryBot.create(:project, repository_url: nil)
      expect(not_git_project).not_to receive(:repo)

      @commits_cleaner.destroy_dangling_commits
    end
  end

  describe "#destroy_old_commits_which_errored_during_import" do
    it "should destroy all errored commits older than 2 days during import" do
      FactoryBot.create_list(:commit, 3, project: @project, created_at: 3.days.ago).
          each { |c| c.add_import_error StandardError.new("This is a fake error") }
      regenerate_elastic_search_indexes

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_old_commits_which_errored_during_import
      expect(@project.commits.count).to eq(0)
    end

    it "should not destroy errored commits imported in last 2 days" do
      FactoryBot.create_list(:commit, 3, project: @project).
          each { |c| c.add_import_error StandardError.new("This is a fake error") }

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_old_commits_which_errored_during_import
      expect(@project.commits.count).to eq(3)
    end
  end

  describe "destroy_old_excess_commits_per_project" do
    it "should destory old commits exceeding 100" do
      FactoryBot.create_list :commit, 100, project: @project, ready: true
      FactoryBot.create_list :commit, 100, project: @project, ready: true, created_at: 3.days.ago
      regenerate_elastic_search_indexes

      expect(@project.commits.count).to eq(200)
      @commits_cleaner.destroy_old_excess_commits_per_project
      expect(@project.commits.count).to eq(100)
      expect(@project.commits.first.created_at).to be > Time.current - 2.days
    end
  end
end
