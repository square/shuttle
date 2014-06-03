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

  before(:all) do
    @user = FactoryGirl.create(:user, role: 'monitor', first_name: "Foo", last_name: "Bar")
    @project = FactoryGirl.create(:project)
    @key = FactoryGirl.create(:key, project: @project)
    @translation = FactoryGirl.create(:translation, key: @key)
    @path_params = { translation_id: @translation.to_param, key_id: @key.to_param, project_id: @project.to_param }
    Issue.delete_all
  end

  before :each do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in @user
    ActionMailer::Base.deliveries.clear
  end

  let(:params) { @path_params.merge(extra_params) }

  describe "#create" do
    subject { xhr :post, :create, params }

    context "with valid issue arguments" do
      let(:extra_params) { {issue: { summary: "this is a unique summary", description: "my description", priority: 1, kind: 1 } } }

      it "creates the issue; renders javascript code to replace the #issues that includes the new issue; and response doesn't include errors; sends issue_created email" do
        expect(Issue.count).to eql(0)
        subject
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

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Foo Bar reported a new issue. Issue Summary: this is a unique summary")
      end
    end

    context "with invalid issue arguments" do
      let(:extra_params) { { issue: { summary: "some fake summary" } } }

      it "doesn't create an issue; response includes the errors; doesn't send an email" do
        subject
        expect(Issue.count).to eql(0)
        expect(response).to be_success
        expect(response.body).to include("Errors:")
        expect(response.body).to include('Description can’t be blank')

        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end

  describe "#update" do
    before(:each) do
      @issue = FactoryGirl.create(:issue, user: @user, translation: @translation)
      ActionMailer::Base.deliveries.clear
    end

    subject { xhr :patch, :update, params }

    context "with valid issue arguments" do
      let(:extra_params) { { id: @issue.id, issue: { summary: "updated summary" } } }

      it "updates the issue; renders javascript code to replace the updated #issue-someID; and response doesn't include errors; sends issue_updated email" do
        subject
        @issue.reload
        expect(Issue.count).to eql(1)
        expect(@issue.summary).to eql("updated summary")

        expect(response).to be_success
        expect(response.body).to_not include("Errors:")
        expect(response.body).to include("$('#issues #issue-wrapper-#{@issue.id}').replaceWith")

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Foo Bar updated an issue. Issue Summary: updated summary")
      end
    end

    context "with invalid issue arguments" do
      let(:extra_params) { { id: @issue.id, issue: { status: "wrong status"} } }

      it "doesn't update an issue; response includes the errors; doesn't send an email" do
        subject
        @issue.reload

        expect(@issue.status).to eql(1)

        expect(response).to be_success
        expect(response.body).to include("Errors:")
        expect(response.body).to include('Status not a number')

        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
