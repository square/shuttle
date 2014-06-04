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

  before(:all) do
    @user = FactoryGirl.create(:user, role: 'monitor', first_name: "Foo", last_name: "Bar")
    @project = FactoryGirl.create(:project)
    @key = FactoryGirl.create(:key, project: @project)
    @translation = FactoryGirl.create(:translation, key: @key)
    @issue = FactoryGirl.create(:issue, user: @user, translation: @translation)
    @path_params = { issue_id: @issue.id }
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
      let(:extra_params) { {comment: { content: "this is a comment" } } }

      it "creates the comment; renders javascript code to replace the '.comments' section of the new comment's issue; response includes the new comment; response doesn't include errors; sends comment_created email" do
        expect(Comment.count).to eql(0)
        subject
        expect(Comment.count).to eql(1)
        comment = Comment.last
        expect(comment.content).to eql("this is a comment")
        expect(comment.user_id).to eql(@user.id)

        expect(response).to be_success
        expect(response.body).to_not include("Errors:")
        expect(response.body).to include("$('#issue-wrapper-#{@issue.id} .comments').replaceWith")
        expect(response.body).to include("id=\\\"comment-#{comment.id}\\\"")

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Foo Bar wrote a new comment to an issue: this is a comment")
      end
    end

    context "with invalid issue arguments" do
      let(:extra_params) { {comment: { content: "" } } }

      it "doesn't create a comment; response includes the errors; doesn't send an email" do
        subject
        expect(Comment.count).to eql(0)
        expect(response).to be_success
        expect(response.body).to include("Errors:")
        expect(response.body).to include("Content can’t be blank")

        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
