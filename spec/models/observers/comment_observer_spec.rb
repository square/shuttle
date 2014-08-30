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

describe Comment do
  context "[email notifications]" do
    context "after_create" do
      it "subscribes the commenter to the issue emails; and sends an email to the subscription list when a new comment is created" do
        issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com"])
        user = FactoryGirl.create(:user, email: "commenter@example.com")

        ActionMailer::Base.deliveries.clear
        comment = FactoryGirl.create(:comment, issue: issue, user: user)
        expect(issue.reload.subscribed_emails).to eql(["test@example.com", "commenter@example.com"])

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first

        expect(email.to).to eql(["test@example.com", "commenter@example.com"])
        expect(email.subject).to include("[Shuttle] Sancho Sample wrote a new comment to an issue")
      end
    end
  end
end
