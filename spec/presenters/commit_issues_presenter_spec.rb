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

describe CommitIssuesPresenter do
  FAKE_LOCALIZED_STATUSES = { 1=>'Open', 2=>'In Progress', 3=>'Resolved' }

  def setup_commit_with_issues
    @commit = FactoryGirl.create(:commit)
    @project = @commit.project
    @key = FactoryGirl.create(:key, project: @project)
    @commit.keys << @key
    @translation = FactoryGirl.create(:translation, key: @key)

    @issues = 4.times.map{ FactoryGirl.create(:issue, translation: @translation) } # create 4 issues. their statuses will default to 1
    @issues.last.update_attributes(status: 2) # set the last issue's status to 2
  end

  context "#issues" do
    it "should return an empty array given a commit with no issues" do
      presenter = CommitIssuesPresenter.new(FactoryGirl.create(:commit))
      expect(presenter.issues).to be_blank
    end

    it "should return the list of issues related to the commit given a commit with issues" do
      setup_commit_with_issues
      presenter = CommitIssuesPresenter.new(@commit)
      expect(presenter.issues.sort).to eql(@issues.sort)
    end
  end

  context "#status_counts" do
    before(:each) do
      I18n.stub(:t).and_call_original
      I18n.stub(:t).with('models.issue.status').and_return(FAKE_LOCALIZED_STATUSES)
    end

    it "should set all counts to 0 given a commit with no issues" do
      presenter = CommitIssuesPresenter.new(FactoryGirl.create(:commit))
      expect(presenter.status_counts).to eql([{ status: 1, status_desc: "Open", count: 0 }, { status: 2, status_desc: "In Progress", count: 0 }, { status: 3, status_desc: "Resolved", count: 0 }])
    end

    it "should return correct counts with a commit with issues" do
      setup_commit_with_issues
      presenter = CommitIssuesPresenter.new(@commit)
      expect(presenter.status_counts).to eql([{ status: 1, status_desc: "Open", count: 3 }, { status: 2, status_desc: "In Progress", count: 1 }, { status: 3, status_desc: "Resolved", count: 0 }])
    end
  end
end
