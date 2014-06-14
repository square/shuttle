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

    before (:each) do
      @user = FactoryGirl.create(:user, role: 'monitor', first_name: "Foo", last_name: "Bar")
      @updater = FactoryGirl.create(:user, role: 'monitor', first_name: "Foo", last_name: "Bar")
      @translation = FactoryGirl.create(:translation)
      FactoryGirl.create(:commit, user: FactoryGirl.create(:user), author_email: "commitauthor@test.com").keys << @translation.key # associate the translation with a commit through key
      ActionMailer::Base.deliveries.clear
    end

    context "after_create" do
      it "sends an email when an issue is created" do
        @issue = FactoryGirl.create(:issue, user: @user, updater: @updater, translation: @translation, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary")
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        mail = ActionMailer::Base.deliveries.first
        expected_email_list = [Shuttle::Configuration.mailer.translators_list, @user.email, @updater.email, @translation.key.commits.last.user.email, 'a@test.com', 'b@test.com', 'commitauthor@test.com']
        expect(mail.to.sort).to eql(expected_email_list.sort)
        expect(mail.subject).to eql("[Shuttle] Foo Bar reported a new issue. Issue Summary: my summary")
        expect(mail.body.to_s).to include("reported a new issue")
        expect(mail.body.to_s).to include("http://test.host/projects/#{@translation.key.project.to_param}/keys/#{@translation.key.to_param}/translations/#{@translation.to_param}#issue-wrapper-#{@issue.id}")
      end
    end

    context "after_update" do
      it "sends an email when an issue is updated" do
        @issue = FactoryGirl.create(:issue, user: @user, updater: @updater, translation: @translation, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary")
        2.times { FactoryGirl.create(:comment, issue: @issue) }
        ActionMailer::Base.deliveries.clear
        @issue.update_attributes(status: Issue::Status::IN_PROGRESS, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com, c@test.com")
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        mail = ActionMailer::Base.deliveries.first
        expected_email_list = [Shuttle::Configuration.mailer.translators_list, @user.email, @updater.email, @translation.key.commits.last.user.email, 'a@test.com', 'b@test.com', 'c@test.com', 'commitauthor@test.com'] + @issue.comments.includes(:user).map { |c| c.user.email }
        expect(mail.to.sort).to eql(expected_email_list.sort)
        expect(mail.subject).to eql("[Shuttle] Foo Bar updated an issue. Issue Summary: my summary")
        expect(mail.body.to_s).to include("updated an issue")
        expect(mail.body.to_s).to include("Was: Open")
        expect(mail.body.to_s).to include("Is: In progress")
        expect(mail.body.to_s).to include("http://test.host/projects/#{@translation.key.project.to_param}/keys/#{@translation.key.to_param}/translations/#{@translation.to_param}#issue-wrapper-#{@issue.id}")
      end

      it "should NOT send an email if nothing was changed" do
        issue = FactoryGirl.create(:issue, user: @user, updater: @updater, translation: @translation, subscribed_emails: "a@test.com,  b@test.com  ,   , a@test.com", summary: "my summary")
        ActionMailer::Base.deliveries.clear
        issue.update_attributes(status: issue.status)
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
