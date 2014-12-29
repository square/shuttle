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

describe ArticleOrCommitIssuesPresenter do
  def setup_commit_with_issues(status_counts={})
    @commit = FactoryGirl.create(:commit)
    @project = @commit.project
    @key = FactoryGirl.create(:key, project: @project)
    @commit.keys << @key
    @translation = FactoryGirl.create(:translation, key: @key)

    @issues = []
    status_counts.each do |status, count|
      count.times do
        issue = FactoryGirl.create(:issue, translation: @translation)
        issue.update_attributes(status: status)
        @issues << issue
      end
    end
  end

  context "#issues" do
    it "should return an empty array given a commit with no issues" do
      presenter = ArticleOrCommitIssuesPresenter.new(FactoryGirl.create(:commit))
      expect(presenter.issues).to be_blank
    end

    it "should return the list of issues related to the commit given a commit with issues" do
      setup_commit_with_issues({Issue::Status::OPEN=>3, Issue::Status::IN_PROGRESS=>1})
      presenter = ArticleOrCommitIssuesPresenter.new(@commit)
      expect(presenter.issues.sort).to eql(@issues.sort)
    end
  end

  context "#status_counts" do
    it "should set all counts to 0 given a commit with no issues" do
      presenter = ArticleOrCommitIssuesPresenter.new(FactoryGirl.create(:commit))
      expect(presenter.status_counts).to eql([{ status: 1, status_desc: "Open", count: 0 }, { status: 2, status_desc: "In progress", count: 0 }, { status: 3, status_desc: "Resolved", count: 0 }, { status: 4, status_desc: "IceBox", count: 0 }])
    end

    it "should return correct counts with a commit with issues" do
      setup_commit_with_issues({Issue::Status::OPEN=>3, Issue::Status::IN_PROGRESS=>1})
      presenter = ArticleOrCommitIssuesPresenter.new(@commit)
      expect(presenter.status_counts).to eql([{ status: 1, status_desc: "Open", count: 3 }, { status: 2, status_desc: "In progress", count: 1 }, { status: 3, status_desc: "Resolved", count: 0 }, { status: 4, status_desc: "IceBox", count: 0 }])
    end
  end

  context "#issues_label_with_pending_count" do
    it "should return 'ISSUES' for a commit with no pending issues" do
      setup_commit_with_issues({Issue::Status::RESOLVED=>1, Issue::Status::ICEBOX=>1})
      presenter = ArticleOrCommitIssuesPresenter.new(@commit)
      expect(presenter.issues_label_with_pending_count).to eql('ISSUES')
    end

    it "should return 'ISSUES (6)' for a commit with 6 pending issues" do
      setup_commit_with_issues({Issue::Status::OPEN=>2, Issue::Status::IN_PROGRESS=>4, Issue::Status::ICEBOX=>1})
      presenter = ArticleOrCommitIssuesPresenter.new(@commit)
      expect(presenter.issues_label_with_pending_count).to eql('ISSUES (6)')
    end
  end

  context "#pending_issues_count" do
    it "should return 0 for a commit with no pending issues" do
      setup_commit_with_issues({Issue::Status::RESOLVED=>1, Issue::Status::ICEBOX=>1})
      presenter = ArticleOrCommitIssuesPresenter.new(@commit)
      expect(presenter.send :pending_issues_count).to eql(0)
    end

    it "should return the correct count for a commit with pending issues" do
      setup_commit_with_issues({Issue::Status::OPEN=>2, Issue::Status::IN_PROGRESS=>4, Issue::Status::ICEBOX=>1})
      presenter = ArticleOrCommitIssuesPresenter.new(@commit)
      expect(presenter.send :pending_issues_count).to eql(6)
    end
  end
end
