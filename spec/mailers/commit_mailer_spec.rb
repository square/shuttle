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
      expect(mail.body).to include("Error Class: Git::CommitNotFoundError", "Error Message: Commit not found in git repo: xyz123 (it may have been rebased away)")
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
