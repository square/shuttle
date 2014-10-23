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

describe CommentsController do
  render_views

  include Devise::TestHelpers

  before(:each) do
    @user = FactoryGirl.create(:user, :confirmed, role: 'monitor', first_name: "Foo", last_name: "Bar", email: "test@example.com")
    @project = FactoryGirl.create(:project)
    @key = FactoryGirl.create(:key, project: @project)
    @translation = FactoryGirl.create(:translation, key: @key)
    @issue = FactoryGirl.create(:issue, user: @user, translation: @translation, subscribed_emails: [])
    @path_params = { issue_id: @issue.id }
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in @user
    ActionMailer::Base.deliveries.clear
  end

  describe "#create" do
    context "with valid comment arguments" do
      it "creates the comment; renders javascript code to replace the '.comments' section of the new comment's issue; response includes the new comment; response doesn't include errors; subscribes user to issue; sends comment_created email; doesn't send issue_updated email" do
        expect(Comment.count).to eql(0)

        xhr :post, :create, @path_params.merge({comment: { content: "this is a comment" } })

        expect(Comment.count).to eql(1)
        comment = Comment.last
        expect(comment.content).to eql("this is a comment")
        expect(comment.user_id).to eql(@user.id)
        expect(@issue.reload.subscribed_emails).to eql(["test@example.com"])

        expect(response).to be_success
        expect(response.body).to_not include("Errors:")
        expect(response.body).to include("$('#issues #issue-wrapper-#{@issue.id}').replaceWith")
        expect(response.body).to include("id=\\\"comment-#{comment.id}\\\"")

        # the below expectations implicitly mean that we don't expect an issue_updated email
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        mail = ActionMailer::Base.deliveries.first
        expect(mail.subject).to eql("[Shuttle] Foo Bar wrote a new comment to an issue: this is a comment")
        expect(mail.to).to eql(["test@example.com"])
      end
    end

    context "with invalid comment arguments" do
      it "doesn't create a comment; response includes the errors; doesn't send an email; doesn't subscribe the user to the issue" do
        xhr :post, :create, @path_params.merge({comment: { content: "" } })

        expect(Comment.count).to eql(0)
        expect(@issue.reload.subscribed_emails).to eql([])
        expect(response).to be_success
        expect(response.body).to include("Errors:")
        expect(response.body).to include("Content can’t be blank")

        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
