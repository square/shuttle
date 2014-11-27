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
  context "[validations]" do
    before :each do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation)
      @issue = FactoryGirl.create(:issue, user: @user, translation: @translation)
    end

    before(:each) do
      @comment = FactoryGirl.build(:comment, user: @user, issue: @issue)
    end

    it "should validate user on create, should have a nil user_nil if user is deleted and should not validate user on update" do
      @comment.user_id = nil
      expect(@comment).to_not be_valid
      @comment.user = @user
      @comment.save

      @user.destroy
      @comment.reload
      expect(@comment.user_id).to be_nil

      @comment.content += "test"
      expect(@comment).to be_valid
    end
  end
end
