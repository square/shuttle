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
describe GithubWebhookPinger do
  before(:each) do
    @commit = FactoryGirl.create(:commit)
  end

  describe "#perform" do
    subject { GithubWebhookPinger.new }

    it "sends an http request to the project webhook_url if one is defined" do
      url = "http://www.example.com"
      @commit.project.github_webhook_url = url
      @commit.project.save!
      expect(HTTParty).to receive(:post).with(url, anything())
      subject.perform(@commit.id)
    end

    it "doesnt send anything if no webhook_url is defined on the project" do
      expect(@commit.project.github_webhook_url).to be_blank
      expect(HTTParty).not_to receive(:post)
      subject.perform(@commit.id)
    end

    it "raises a Project::NotLinkedToAGitRepositoryError if project doesn't have a repository_url" do
      @commit.project.update! repository_url: nil
      expect(HTTParty).not_to receive(:post)
      expect { subject.perform(@commit.id) }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end
  end
end
