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
    before :each do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation)
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

      it "should not allow kind greater than 7" do
        @issue.kind = 8
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

  context "#new_with_defaults" do
    it "initializes a new Issue with default subscribed_emails which contains the translators_list email address" do
      expect(Issue.new_with_defaults.subscribed_emails).to eql([Shuttle::Configuration.app.mailer.translators_list])
    end
  end

  context "#resolve" do
    it "resolves an issue by setting its status to resolved, subscribes the user to the issue" do
      issue = FactoryGirl.create(:issue, status: Issue::Status::OPEN, subscribed_emails: ["test@example.com"])
      user = FactoryGirl.create(:user, email: "test2@example.com")
      issue.resolve(user)
      expect(issue.reload.status).to eql(Issue::Status::RESOLVED)
      expect(issue.subscribed_emails).to eql(["test@example.com", "test2@example.com"])
    end

    it "resolves an issue by setting its status to resolved; doesn't change subscriptions if the user is already subscribed" do
      issue = FactoryGirl.create(:issue, status: Issue::Status::OPEN, subscribed_emails: ["test@example.com"])
      user = FactoryGirl.create(:user, email: "test@example.com")
      issue.resolve(user)
      expect(issue.reload.status).to eql(Issue::Status::RESOLVED)
      expect(issue.subscribed_emails).to eql(["test@example.com"])
    end
  end

  context "[subscribed_emails=]" do
    before(:each) do
      @user = FactoryGirl.create(:user)
      @translation = FactoryGirl.create(:translation)
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

  context "#subscribe" do
    before :each do
      @issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com"])
    end

    it "subscribes a new user's email address" do
      user = FactoryGirl.create(:user, email: "test2@example.com")
      @issue.subscribe(user)
      expect(@issue.reload.subscribed_emails).to eq(["test@example.com", "test2@example.com"])
    end

    it "doesn't change subscribed_emails if the user's email address is already subscribed" do
      user = FactoryGirl.create(:user, email: "test@example.com")
      @issue.subscribe(user)
      expect(@issue.reload.subscribed_emails).to eq(["test@example.com"])
    end
  end

  context "#unsubscribe" do
    before :each do
      @issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com"])
    end

    it "unsubscribes a user's email address" do
      user = FactoryGirl.create(:user, email: "test@example.com")
      @issue.unsubscribe(user)
      expect(@issue.reload.subscribed_emails).to eq([])
    end

    it "doesn't change subscribed_emails if the email address is not in the subscribed list" do
      user = FactoryGirl.create(:user, email: "test2@example.com")
      @issue.unsubscribe(user)
      expect(@issue.reload.subscribed_emails).to eq(["test@example.com"])
    end
  end

  context "#subscribed?" do
    it "should return true if the given user's email is in the subscribed_emails list" do
      issue = FactoryGirl.create(:issue, subscribed_emails: ["test@example.com"])
      user = FactoryGirl.create(:user, email: "test@example.com")
      expect(issue.subscribed?(user)).to be_true
    end

    it "should return false if the given user's email is not in the subscribed_emails list" do
      issue = FactoryGirl.create(:issue, subscribed_emails: ["other@example.com"])
      user = FactoryGirl.create(:user, email: "test@example.com")
      expect(issue.subscribed?(user)).to be_false
    end
  end

  context "[hooks]" do
    it "sets status to Open on create" do
      issue = FactoryGirl.build(:issue, user: nil, translation: nil, status: -1111)
      issue.valid?
      expect(issue.status).to eql(Issue::Status::OPEN)
    end
  end

  context "[scopes]" do
    context "[resolved]" do
      context "#resolved?" do
        it "should be resolved if issue's status is RESOLVED" do
          expect(FactoryGirl.build(:issue, status: Issue::Status::RESOLVED)).to be_resolved
        end

        it "should not be resolved if issue's status is OPEN" do
          expect(FactoryGirl.build(:issue, status: Issue::Status::OPEN)).to_not be_resolved
        end
      end
    end

    context "[pending]" do
      context "#pending?" do
        it "should be pending for an issue with status OPEN" do
          expect(FactoryGirl.build(:issue, status: Issue::Status::OPEN)).to be_pending
        end

        it "should be pending for an issue with status IN PROGRESS" do
          expect(FactoryGirl.build(:issue, status: Issue::Status::IN_PROGRESS)).to be_pending
        end

        it "should NOT be pending for an issue with status RESOLVED" do
          expect(FactoryGirl.build(:issue, status: Issue::Status::RESOLVED)).to_not be_pending
        end

        it "should NOT be pending for an issue with status ICEBOX" do
          expect(FactoryGirl.build(:issue, status: Issue::Status::ICEBOX)).to_not be_pending
        end
      end

      context "Issue.pending" do
        it "should return no issues if there are no pending issues" do
          issue = FactoryGirl.create(:issue)
          issue.update_attributes(status: Issue::Status::ICEBOX)
          expect(Issue.pending).to be_blank
        end

        it "should return pending issues" do
          issue = FactoryGirl.create(:issue)
          issue.update_attributes(status: Issue::Status::ICEBOX)
          pending_issue = FactoryGirl.create(:issue)
          expect(Issue.pending.to_a).to eql([pending_issue])
        end
      end
    end
  end

  describe "#long_summary" do
    it "returns kind and summary information in 'kind - summary' format if summary exists" do
      issue = FactoryGirl.create(:issue, summary: "hello world", kind: 2)
      expect(issue.long_summary).to eql("Typo - hello world")
    end

    it "returns kind information unless summary exists" do
      issue = FactoryGirl.create(:issue, kind: 2, summary: nil)
      expect(issue.long_summary).to eql("Typo")
    end
  end
end
