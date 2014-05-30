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
  context "[validations]" do
    before(:all) do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation)
    end

    before(:each) do
      @issue = FactoryGirl.build(:issue, user: @user, translation: @translation)
    end

    it "should not allow priority less than -1" do
      @issue.priority = -2
      expect(@issue).not_to be_valid
    end

    it "should not allow priority greater than 3" do
      @issue.priority = 4
      expect(@issue).not_to be_valid
    end

    it "should not allow kind less than 1" do
      @issue.kind = 0
      expect(@issue).not_to be_valid
    end

    it "should not allow kind greater than 6" do
      @issue.kind = 7
      expect(@issue).not_to be_valid
    end

    it "should validate user on create, should have a nil user_nil if user is deleted and should not validate user on update" do
      @issue.user_id = nil
      expect(@issue).to_not be_valid
      @issue.user = @user
      @issue.save

      @user.destroy
      @issue.reload
      expect(@issue.user_id).to be_nil

      @issue.summary += "test"
      expect(@issue).to be_valid
    end
  end

  context "[hooks]" do
    it "sets status to Open on create" do
      issue = FactoryGirl.build(:issue, user: nil, translation: nil, status: -1111)
      issue.valid?
      expect(issue.status).to eql(Issue::Status::OPEN)
    end
  end
end
