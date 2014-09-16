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

describe CommitCreator do
  describe "#perform" do
    context "[rescue Git::CommitNotFoundError]" do
      before :each do
        @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
        @user = FactoryGirl.create(:user, email: "foo@example.com")
        ActionMailer::Base.deliveries.clear
      end

      it "rescues from Git::CommitNotFoundError error and sends an email" do
        CommitCreator.new.perform(@project.id, "xyz123", {"other_fields" => {:user_id => @user.id}})
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eql(["foo@example.com"])
        expect(mail.subject).to eql("[Shuttle] Import Failed for sha: xyz123")
        expect(mail.body).to include("Error Class:   Git::CommitNotFoundError", "Error Message: Commit not found in git repo: xyz123")
      end

      it "rescues from Git::CommitNotFoundError error but doesn't send an email if given user_id is nil" do
        CommitCreator.new.perform(@project.id, "xyz123", {:other_fields => {:user_id => nil}})
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end

    context "[rescue Project::NotLinkedToAGitRepositoryError]" do
      before :each do
        @project = FactoryGirl.create(:project, repository_url: nil)
        @user = FactoryGirl.create(:user, email: "foo@example.com")
        ActionMailer::Base.deliveries.clear
      end

      it "rescues from Project::NotLinkedToAGitRepositoryError error and sends an email" do
        CommitCreator.new.perform(@project.id, "xyz123", {"other_fields" => {:user_id => @user.id}})
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eql(["foo@example.com"])
        expect(mail.subject).to eql("[Shuttle] Import Failed for sha: xyz123")
        expect(mail.body).to include("Error Class:   Project::NotLinkedToAGitRepositoryError", "Error Message: repository_url is empty")
      end

      it "rescues from Project::NotLinkedToAGitRepositoryError error but doesn't send an email if given user_id is nil" do
        CommitCreator.new.perform(@project.id, "xyz123", {:other_fields => {:user_id => nil}})
        expect(ActionMailer::Base.deliveries.size).to eql(0)
      end
    end
  end
end
