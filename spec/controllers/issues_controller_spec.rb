# encoding: utf-8

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

describe IssuesController do
  render_views

  include Devise::TestHelpers

  before :each do
    @user = FactoryGirl.create(:user, :confirmed, role: 'monitor', first_name: "Foo", last_name: "Bar", email: "foo@bar.com")
    @project = FactoryGirl.create(:project)
    @key = FactoryGirl.create(:key, project: @project)
    @translation = FactoryGirl.create(:translation, key: @key)
    @path_params = { translation_id: @translation.to_param, key_id: @key.to_param, project_id: @project.to_param }
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in @user
    ActionMailer::Base.deliveries.clear
  end

  describe "#create" do
    context "with valid issue arguments" do
      [ { issue: { summary: "this is a unique summary", description: "my description", kind: 1, priority: 1, subscribed_emails: "test1@example.com, test2@example.com, test1@example.com" } },
        { issue: { summary: "this is a unique summary", description: "my description", kind: 1, priority: nil, subscribed_emails: "" } },
        { issue: { summary: "this is a unique summary", description: "my description", kind: 1, priority: '' } },
        { issue: { summary: "this is a unique summary", description: "my description", kind: 1 } }
      ].each do |extra_params|
        let(:extra_params) { extra_params }

        it "creates the issue; renders javascript code to replace the #issues that includes the new issue; and response doesn't include errors; sends issue_created email" do
          expect(Issue.count).to eql(0)

          xhr :post, :create, @path_params.merge(extra_params)

          expect(Issue.count).to eql(1)
          issue = Issue.last
          expect(issue.summary).to eql("this is a unique summary")
          expect(issue.description).to eql("my description")
          expect(issue.status).to eql(Issue::Status::OPEN)
          expect(issue.translation_id).to eql(@translation.id)

          expect(response).to be_success
          expect(response.body).to_not include("Errors:")
          expect(response.body).to include("$('#issues').replaceWith")
          expect(response.body).to include("id=\\\"issues\\\"")
          expect(response.body).to include("id=\\\"issue-#{issue.id}\\\"")

          if extra_params[:issue][:subscribed_emails].present?
            expect(ActionMailer::Base.deliveries.size).to eql(1)
            expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Foo Bar reported a new issue. Issue Summary: Needs More Context - this is a unique summary")
          else
            expect(ActionMailer::Base.deliveries.size).to eql(0)
          end
        end
      end
    end

    context "with invalid issue arguments" do
      let(:extra_params) { { issue: { subscribed_emails: "a@b.com,  a@b.com  ,  abc xyz, abc@abc, abc.com", priority: 30 } } }

      it "doesn't create an issue; response includes the errors; doesn't send an email" do
        xhr :post, :create, @path_params.merge(extra_params)
        expect(Issue.count).to eql(0)
        expect(response).to be_success
        expect(response.body).to include("Errors:")
        expect(response.body).to include('Priority must be less than or equal to 3')
        expect(response.body).to include('Kind not a number')
        expect(response.body).to include('Subscribed email abc xyz is not a valid email address')
        expect(response.body).to include('Subscribed email abc@abc is not a valid email address')
        expect(response.body).to include('Subscribed email abc.com is not a valid email address')
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end

  describe "#update" do
    before(:each) do
      @issue = FactoryGirl.create(:issue, user: @user, translation: @translation)
      ActionMailer::Base.deliveries.clear
    end

    context "with valid issue arguments" do
      it "updates the issue; renders javascript code to replace the updated #issue-someID; and response doesn't include errors; sends issue_updated email" do
        xhr :patch, :update, @path_params.merge({ id: @issue.id, issue: { summary: "this is a unique summary updated", description: "my description updated", priority: 2, kind: 2, status: Issue::Status::RESOLVED, subscribed_emails: "a@b.com, c@d.com" } })

        @issue.reload
        expect(Issue.count).to eql(1)
        expect(@issue.summary).to eql("this is a unique summary updated")
        expect(@issue.description).to eql("my description updated")
        expect(@issue.priority).to eql(2)
        expect(@issue.kind).to eql(2)
        expect(@issue.status).to eql(Issue::Status::RESOLVED)
        expect(@issue.subscribed_emails).to eql(%w(a@b.com c@d.com))

        expect(response).to be_success
        expect(response.body).to_not include("Errors:")
        expect(response.body).to include("$('#issues #issue-wrapper-#{@issue.id}').replaceWith")

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Foo Bar updated an issue. Issue Summary: Typo - this is a unique summary updated")
      end
    end

    context "with invalid issue arguments" do
      it "doesn't update an issue; response includes the errors; doesn't send an email" do
        xhr :patch, :update, @path_params.merge({ id: @issue.id, issue: { status: "wrong status", subscribed_emails: "xyz" } })
        @issue.reload

        expect(@issue.status).to eql(1)

        expect(response).to be_success
        expect(response.body).to include("Errors:")
        expect(response.body).to include('Status not a number')
        expect(response.body).to include('Subscribed email xyz is not a valid email address')

        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end

  describe "#resolve" do
    it "resolves the issue, subscribes the current user, and sends an email" do
      issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com"], translation: @translation)
      ActionMailer::Base.deliveries.clear

      expect(issue).to_not be_resolved
      xhr :patch, :resolve, @path_params.merge({ id: issue.id })
      expect(issue.reload).to be_resolved
      expect(issue.reload.subscribed_emails).to eql(["test@example.com", "foo@bar.com"])
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      expect(ActionMailer::Base.deliveries.first.subject).to include("updated an issue. Issue Summary:")
      expect(ActionMailer::Base.deliveries.first.to).to eql(["test@example.com", "foo@bar.com"])
    end
  end

  describe "#subscribe" do
    it "subscribes the current user to the issue, but doesn't send an email" do
      issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com"], translation: @translation)
      ActionMailer::Base.deliveries.clear

      xhr :patch, :subscribe, @path_params.merge({ id: issue.id })
      expect(issue.reload.subscribed_emails).to eql(["test@example.com", "foo@bar.com"])
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end
  end

  describe "#unsubscribe" do
    it "unsubscribes the current user from the issue and sends an email" do
      issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com", "foo@bar.com"], translation: @translation)
      ActionMailer::Base.deliveries.clear

      xhr :patch, :unsubscribe, @path_params.merge({ id: issue.id })
      expect(issue.reload.subscribed_emails).to eql(["test@example.com"])
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end
  end
end
