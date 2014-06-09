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

    context "[priority]" do
      it "should not allow priority less than 0" do
        @issue.priority = -1
        expect(@issue).to_not be_valid
      end

      it "should not allow priority greater than 3" do
        @issue.priority = 4
        expect(@issue).to_not be_valid
      end

      it "should allow priority nil" do
        @issue.priority = nil
        expect(@issue).to be_valid
      end
    end

    context "[kind]" do
      it "should not allow kind less than 1" do
        @issue.kind = 0
        expect(@issue).to_not be_valid
      end

      it "should not allow kind greater than 6" do
        @issue.kind = 7
        expect(@issue).to_not be_valid
      end
    end

    context "[user]" do
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

    context "[subscribed_emails]" do
      it "should not have errors when set to nil" do
        @issue.subscribed_emails = nil
        expect(@issue).to be_valid
      end

      it "should not have errors when set to empty string" do
        @issue.subscribed_emails = ""
        expect(@issue).to be_valid
      end

      it "should not have errors when set to 1 valid email address" do
        @issue.subscribed_emails = "a@b.com"
        expect(@issue).to be_valid
      end

      it "should not have errors when set to multiple valid unique email addresses" do
        @issue.subscribed_emails = "a@b.com, c@d.com"
        expect(@issue).to be_valid
      end

      it "should have errors if there are malformed email addresses" do
        @issue.subscribed_emails = "a@b.com, hello , , a @b.com, a@b.com, hello"
        expect(@issue.tap(&:valid?).errors.full_messages).to eql(["Subscribed email hello is not a valid email address", "Subscribed email a @b.com is not a valid email address"])
      end
    end
  end

  context "[subscribed_emails=]" do
    before(:all) do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation)
    end

    before(:each) do
      @issue = FactoryGirl.build(:issue, user: @user, translation: @translation)
    end

    it "should handle nil" do
      @issue.subscribed_emails = nil
      @issue.subscribed_emails == []
    end

    it "should handle empty string" do
      @issue.subscribed_emails = ""
      @issue.subscribed_emails == []
    end

    it "should handle a single email address" do
      @issue.subscribed_emails = "a@b.com"
      @issue.subscribed_emails == %w(a@b.com)
    end

    it "should split string email addresses by commas" do
      @issue.subscribed_emails = "a@b.com, c@d.com"
      @issue.subscribed_emails == %w(a@b.com c@d.com)
    end

    it "should strip email addresses of blank spaces" do
      @issue.subscribed_emails = "  a@b.com    ,   c@d.com   "
      @issue.subscribed_emails == %w(a@b.com c@d.com)

    end

    it "should discard blank email addresses" do
      @issue.subscribed_emails = " ,  a ,   ,   a@b.com, , , c@d.com"
      @issue.subscribed_emails == %w(a a@b.com c@d.com)
    end

    it "should discard duplicate email addresses" do
      @issue.subscribed_emails = "a@b.com, c@d.com, c@d.com, a@b.com"
      @issue.subscribed_emails == %w(a@b.com c@d.com)
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
