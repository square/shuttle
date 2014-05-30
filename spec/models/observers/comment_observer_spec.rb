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
      it "should send an email to everyone who commented before, people who created and updated the issue, and the translators list" do
        @issue = FactoryGirl.create(:issue)
        @user1 = FactoryGirl.create(:user, email: "first_commenter@test.com")
        @user2 = FactoryGirl.create(:user, email: "second_commenter@test.com")
        FactoryGirl.create(:comment, issue: @issue, user: @user1)
        ActionMailer::Base.deliveries.clear

        @comment = FactoryGirl.create(:comment, issue: @issue, user: @user2, content: "This is awesome")
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first
        expected_email_list = [Shuttle::Configuration.mailer.translators_list, "first_commenter@test.com", "second_commenter@test.com", @issue.user.email, @issue.updater.email]
        expect(email.to.sort).to eql(expected_email_list.sort)
        expect(email.subject).to eql("[Shuttle] Sancho Sample wrote a new comment to an issue: 'This is awesome'.")
        expect(email.body.to_s).to include("wrote a new comment")
        expect(email.body.to_s).to include("http://test.host/projects/#{@issue.translation.key.project.to_param}/keys/#{@issue.translation.key.to_param}/translations/#{@issue.translation.to_param}#comment-#{@comment.id}")
      end
    end
  end
end
