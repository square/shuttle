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

require "spec_helper"

describe IssueMailer do
  context "issue_created" do
    it "sends an email notifying people that issue was created" do
      user = FactoryGirl.create(:user, first_name: "Test", last_name: "User")
      issue = FactoryGirl.create(:issue, user: user, subscribed_emails: "a@example.com, b@example.com  ,   , a@example.com", summary: "my summary", kind: 1)
      ActionMailer::Base.deliveries.clear
      IssueMailer.issue_created(issue).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eql(['a@example.com', 'b@example.com'])
      expect(mail.subject).to eql("[Shuttle] Test User reported a new issue. Issue Summary: Needs More Context - my summary")
      expect(mail.body.to_s).to include("reported a new issue")
      expect(mail.body.to_s).to include(project_key_translation_url(issue.translation.key.project, issue.translation.key, issue.translation) + "#issue-wrapper-#{issue.id}")
    end

    it "doesn't send an email if nobody is subscribed to the issue" do
      issue = FactoryGirl.create(:issue, subscribed_emails: "")
      ActionMailer::Base.deliveries.clear
      IssueMailer.issue_created(issue).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end
  end

  context "issue_updated" do
    it "sends an email notifying people that issue was updated" do
      issue = FactoryGirl.create(:issue, subscribed_emails: "a@example.com, b@example.com", summary: "my summary", kind: 1)
      user = FactoryGirl.create(:user, first_name: "Test", last_name: "User")
      ActionMailer::Base.deliveries.clear
      issue.update!(updater: user, status: Issue::Status::IN_PROGRESS, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com, c@test.com")
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eql(["a@test.com", "b@test.com", "c@test.com"])
      expect(mail.subject).to eql("[Shuttle] Test User updated an issue. Issue Summary: Needs More Context - my summary")
      expect(mail.body.to_s).to include("updated an issue")
      expect(mail.body.to_s).to include("Was: Open")
      expect(mail.body.to_s).to include("Is: In progress")
      expect(mail.body.to_s).to include(project_key_translation_url(issue.translation.key.project, issue.translation.key, issue.translation) + "#issue-wrapper-#{issue.id}")
    end

    it "doesn't send an email if nobody is subscribed to the issue" do
      issue = FactoryGirl.create(:issue, subscribed_emails: "")
      ActionMailer::Base.deliveries.clear
      IssueMailer.issue_updated(issue).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end
  end
end
