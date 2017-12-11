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

require 'spec_helper'

describe CommitsCleaner do
  before :each do
    allow_any_instance_of(Project).to receive(:repo).and_return(nil)
    StashWebhookHelper.stub_chain(:new, :ping).and_return(nil)
    @commits_cleaner = CommitsCleaner.new
    @project = FactoryGirl.create(:project, :light)
  end

  describe "#destroy_dangling_commits" do
    before :each do
      allow_any_instance_of(Commit).to receive(:commit).and_raise(Rugged::OdbError)
    end

    it "should destory all commits" do
      create_commits(@project, 3)

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_dangling_commits
      expect(@project.commits.count).to eq(0)
    end

    it "should not destory any ready commits" do
      create_commits(@project, 3, ready: true)

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_dangling_commits
      expect(@project.commits.count).to eq(3)
    end
  end

  describe "#destroy_old_commits_which_errored_during_import" do
    it "should destroy all errored commits older than 2 days during import" do
      create_commits(@project, 3, created_at: Time.current - 3.days).each { |commit| commit.add_import_error(StandardError.new("This is a fake error"))}

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_old_commits_which_errored_during_import
      expect(@project.commits.count).to eq(0)
    end

    it "should not destroy errored commits imported in last 2 days" do
      create_commits(@project, 3).each { |commit| commit.add_import_error(StandardError.new("This is a fake error"))}

      expect(@project.commits.count).to eq(3)
      @commits_cleaner.destroy_old_commits_which_errored_during_import
      expect(@project.commits.count).to eq(3)
    end
  end

  describe "destroy_old_excess_commits_per_project" do
    it "should destory old commits exceeding 100" do
      create_commits(@project, 100, ready: true)
      create_commits(@project, 100, ready: true, created_at: Time.current - 3.days)

      expect(@project.commits.count).to eq(200)
      @commits_cleaner.destroy_old_excess_commits_per_project
      expect(@project.commits.count).to eq(100)
      expect(@project.commits.first.created_at).to be > Time.current - 2.days
    end
  end

  private

  def create_commits(project, num=1, data={})
    num.times.map { |i| FactoryGirl.create(:commit, project: project, **data) }
  end
end
