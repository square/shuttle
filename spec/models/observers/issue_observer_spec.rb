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

    before(:each) do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation)

      ActionMailer::Base.deliveries.clear
      @issue = FactoryGirl.create(:issue, translation: @translation, user: @user, updater: @user, summary: 'Some fake issue')
    end

    context "after_create" do
      it "should send an email to the right people" do
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first
        expected_email_list = [Shuttle::Configuration.mailer.translators_list, @user.email]
        expect(email.to.sort).to eql(expected_email_list.sort)
        expect(email.subject).to eql("[Shuttle] Sancho Sample reported a new issue. Issue Summary: 'Some fake issue'")
        expect(email.body.to_s).to include("reported a new issue")
        expect(email.body.to_s).to include("http://test.host/projects/#{@translation.key.project.to_param}/keys/#{@translation.key.to_param}/translations/#{@translation.to_param}#issue-wrapper-#{@issue.id}")
      end
    end

    context "after_update" do
      before(:each) do
        ActionMailer::Base.deliveries.clear
      end

      it "should send an email" do
        @issue.update_attributes(status: 2)
        expect(ActionMailer::Base.deliveries.size).to eql(1)

        email = ActionMailer::Base.deliveries.first
        expect(email.subject).to eql("[Shuttle] Sancho Sample updated an issue. Issue Summary: 'Some fake issue'")
        expect(email.body.to_s).to include("updated an issue")
        expect(email.body.to_s).to include("Was: Open")
        expect(email.body.to_s).to include("Is: In progress")
        expect(email.body.to_s).to include("http://test.host/projects/#{@translation.key.project.to_param}/keys/#{@translation.key.to_param}/translations/#{@translation.to_param}#issue-wrapper-#{@issue.id}")
      end

      it "should NOT send an email if nothing was changed" do
        @issue.update_attributes(status: @issue.status)
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
