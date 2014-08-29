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

describe CommentMailer do
  context "[comment_created]" do
    it "doesn't send an email if subscribed_emails list is empty" do
      comment = FactoryGirl.create(:comment)
      comment.issue.update! subscribed_emails: []
      ActionMailer::Base.deliveries.clear
      CommentMailer.comment_created(comment).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end

    it "sends an email notifying the subscribed people about the new commit" do
      user = FactoryGirl.create(:user, first_name: "Test", last_name: "User")
      comment = FactoryGirl.create(:comment, user: user, content: "This is awesome")
      comment.issue.update! subscribed_emails: ["test1@example.com", "test2@example.com"]
      ActionMailer::Base.deliveries.clear
      CommentMailer.comment_created(comment).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      email = ActionMailer::Base.deliveries.first
      expect(email.to).to eql(["test1@example.com", "test2@example.com"])
      expect(email.subject).to eql("[Shuttle] Test User wrote a new comment to an issue: This is awesome")
      expect(email.body.to_s).to include("wrote a new comment")
      expect(email.body.to_s).to include(project_key_translation_url(comment.issue.translation.key.project, comment.issue.translation.key, comment.issue.translation) + "#comment-#{comment.id}")
    end
  end
end
