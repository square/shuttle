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

describe ProjectsController do
  describe '#github_webhook' do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, watched_branches: [ 'master' ])
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, role: 'monitor')
      sign_in @user
      @request.accept = "application/json"
      post :github_webhook, { id: @project.to_param, payload: "{\"ref\":\"refs/head/master\",\"after\":\"HEAD\"}" }
    end

    it "should return 200 and create a github commit for the current user" do
      expect(response.status).to eql(200)
      expect(@project.commits.first.user).to eql(@user)
      expect(@project.commits.first.description).to eql('github webhook')
    end
  end

  describe '#stash_webhook' do
    it "returns 200 if project has a repository_url" do
      project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      expect(CommitCreator).to receive(:perform_once).once
      post :stash_webhook, { id: project.to_param, sha: "HEAD" }
      expect(response).to be_ok
    end

    it "returns 400 if project doesn't have a repository_url" do
      project = Project.create(name: "Test")
      expect(CommitCreator).to_not receive(:perform_once)
      post :stash_webhook, { id: project.to_param, sha: "HEAD" }
      expect(response.status).to eql(400)
    end
  end
end
