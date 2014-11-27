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

describe Issue do
  context "[email notifications]" do
    context "after_create" do
      it "sends an email when an issue is created" do
        expect(IssueMailer).to receive(:issue_created).once.and_call_original
        issue = FactoryGirl.build(:issue, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary", kind: 1)
        ActionMailer::Base.deliveries.clear
        issue.save!
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("reported a new issue. Issue Summary: Needs More Context - my summary")
      end
    end

    context "after_update" do
      it "sends an email if an issue is updated when skip_email_notifications is not set" do
        issue = FactoryGirl.create(:issue, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary", kind: 1)
        ActionMailer::Base.deliveries.clear
        expect(IssueMailer).to receive(:issue_updated).once.and_call_original
        issue.update!(status: Issue::Status::IN_PROGRESS, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com, c@test.com")
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("updated an issue. Issue Summary: Needs More Context - my summary")
      end

      it "doesn't send an email if an issue is updated when skip_email_notifications is set" do
        issue = FactoryGirl.create(:issue, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary", kind: 1)
        ActionMailer::Base.deliveries.clear
        expect(IssueMailer).to_not receive(:issue_updated)
        issue.update!(status: Issue::Status::IN_PROGRESS, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com, c@test.com", skip_email_notifications: true)
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end

      it "should NOT send an email if nothing was changed (other than timestamps)" do
        issue = FactoryGirl.create(:issue, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary")
        ActionMailer::Base.deliveries.clear
        expect(IssueMailer).to_not receive(:issue_updated)
        issue.update!(status: issue.status)
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
