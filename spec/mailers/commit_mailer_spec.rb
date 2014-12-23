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

require "spec_helper"

describe CommitMailer do
  describe "#notify_submitter_of_import_errors" do
    before :each do
      @project = FactoryGirl.create(:project)
      @commit = FactoryGirl.create(:commit, project: @project, author_email: "foo@example.com")
      ActionMailer::Base.deliveries.clear
    end

    context "[sends an email with import errors]" do
      def set_import_errors_and_expect_an_email_with_them_return_mail_object(commit, errors)
        commit.update import_errors: errors
        CommitMailer.notify_submitter_of_import_errors(commit).deliver
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eql(["foo@example.com"])
        expect(mail.subject).to eql("[Shuttle] Error(s) occurred during the import")
        errors.each { |err_class, err_message| expect(mail.body).to include("#{err_class} - #{err_message}") }
        mail
      end

      it "with all the errors and with the extra explanation for Git::NotFoundErors, if there are both Git::CommitNotFoundError and Git::BlobNotFoundError" do
        fake_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                       ["Git::BlobNotFoundError", "Blob not found in git repo: 88e5b52732c23a4e33471d91cf2281e62021512a (failed in BlobImporter for commit_id #{@commit.id} and blob 88e5b52732c23a4e33471d91cf2281e62021512a)"],
                       ["Git::CommitNotFoundError", "Commit not found in git repo: fake_sha (failed in CommitKeyCreator for commit_id #{@commit.id} and blob b80d7482dba100beb55e65e82c5edb28589fa045)"],
                       ["Psych::SyntaxError", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1 (in /config/locales/ruby/broken.yml)"],
                       ["V8::Error", "Unexpected identifier at <eval>:2:12 (in /ember-broken/en-US.js)"]]

        mail = set_import_errors_and_expect_an_email_with_them_return_mail_object(@commit, fake_errors)
        expect(mail.body).to include("Shuttle couldn't find at least one sha from your commit in the git repo. This typically happens when your commit gets rebased away. Please submit the new sha to be able to get your strings translated.")
      end

      it "and with the extra explanation for Git::NotFoundErors, if there is a Git::CommitNotFoundError and no Git::BlobNotFoundError" do
        fake_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                       ["Git::CommitNotFoundError", "Commit not found in git repo: fake_sha (failed in CommitKeyCreator for commit_id #{@commit.id} and blob b80d7482dba100beb55e65e82c5edb28589fa045)"]]

        mail = set_import_errors_and_expect_an_email_with_them_return_mail_object(@commit, fake_errors)
        expect(mail.body).to include("Shuttle couldn't find at least one sha from your commit in the git repo. This typically happens when your commit gets rebased away. Please submit the new sha to be able to get your strings translated.")
      end

      it "and with the extra explanation for Git::NotFoundErors, if there is no Git::CommitNotFoundError and 1 Git::BlobNotFoundError" do
        fake_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                       ["Git::BlobNotFoundError", "Blob not found in git repo: 88e5b52732c23a4e33471d91cf2281e62021512a (failed in BlobImporter for commit_id #{@commit.id} and blob 88e5b52732c23a4e33471d91cf2281e62021512a)"]]

        mail = set_import_errors_and_expect_an_email_with_them_return_mail_object(@commit, fake_errors)
        expect(mail.body).to include("Shuttle couldn't find at least one sha from your commit in the git repo. This typically happens when your commit gets rebased away. Please submit the new sha to be able to get your strings translated.")
      end

      it "but without the extra explanation for Git::NotFoundErors, if there are no Git::NotFoundError" do
        fake_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"]]

        mail = set_import_errors_and_expect_an_email_with_them_return_mail_object(@commit, fake_errors)
        expect(mail.body).to_not include("Shuttle couldn't find at least one sha from your commit in the git repo.", "rebased")
      end
    end

    it "doesn't send an email if there are no import errors" do
      @commit.update import_errors: []
      CommitMailer.notify_submitter_of_import_errors(@commit).deliver
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "doesn't send an email if there is no author email and submitter user" do
      @commit.update author_email: nil, user: nil
      CommitMailer.notify_submitter_of_import_errors(@commit).deliver
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "#notify_import_errors_in_commit_creator" do
    before :each do
      @project = FactoryGirl.create(:project)
      ActionMailer::Base.deliveries.clear
    end

    it "sends an email to the user if user_id is valid" do
      user = FactoryGirl.create(:user, email: "example@example.com")
      ActionMailer::Base.deliveries.clear
      CommitMailer.notify_import_errors_in_commit_creator(user.id, @project.id, "xyz123", Git::CommitNotFoundError.new("xyz123")).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eql(["example@example.com"])
      expect(mail.subject).to eql("[Shuttle] Import Failed for sha: xyz123")
      expect(mail.body).to include("Error Class:   Git::CommitNotFoundError", "Error Message: Commit not found in git repo: xyz123")
      expect(mail.body).to include("Shuttle couldn't find your sha 'xyz123' in the git repo. This typically happens when your commit gets rebased away or the sha was invalid. Please submit the new sha to be able to get your strings translated.")
    end

    it "sends an email to the user if user_id is valid, but doesn't include the extra explanation about rebasing if the error is not related to Git::NotFoundError" do
      user = FactoryGirl.create(:user, email: "example@example.com")
      ActionMailer::Base.deliveries.clear
      CommitMailer.notify_import_errors_in_commit_creator(user.id, @project.id, "xyz123", StandardError.new("random message")).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eql(["example@example.com"])
      expect(mail.subject).to eql("[Shuttle] Import Failed for sha: xyz123")
      expect(mail.body).to include("Error Class:   StandardError", "Error Message: random message")
      expect(mail.body).to_not include("git repo", "rebased")
    end

    it "doesn't send an email if user_id is nil" do
      CommitMailer.notify_import_errors_in_commit_creator(nil, @project.id, "xyz123", Git::CommitNotFoundError.new("xyz123")).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end

    it "doesn't send an email if we cannot find a user with user_id" do
      expect(User).to receive(:find_by_id).once.and_call_original
      CommitMailer.notify_import_errors_in_commit_creator(0, @project.id, "xyz123", Git::CommitNotFoundError.new("xyz123")).deliver
      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end
  end
end
