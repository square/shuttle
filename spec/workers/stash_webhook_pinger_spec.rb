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
describe StashWebhookPinger do
  include Rails.application.routes.url_helpers

  before(:each) do
    allow(Kernel).to receive(:sleep)
    allow(HTTParty).to receive(:post)
  end

  after(:each) do
    Commit.destroy_all
  end

  describe "#perform" do
    subject { StashWebhookPinger.new }

    context "on_perform" do
      before(:each) do
        @commit = FactoryGirl.create(:commit)
      end

      it "sends an http request to the project stash_webhook_url 10 times if one is defined" do
        url = "http://www.example.com"
        @commit.project.stash_webhook_url = url
        @commit.project.save!
        expect(HTTParty).to receive(:post).with(
                                "#{url}/#{@commit.revision}",
                                anything()
                            ).exactly(StashWebhookHelper::DEFAULT_NUM_TIMES).times
        subject.perform(@commit.id)
      end

      it "should make sure that the commit is reloaded with the proper state" do
        url = "http://www.example.com"
        @commit.project.stash_webhook_url = url
        @commit.project.save!

        expect(HTTParty).to receive(:post) do |url, params|
          commit_state = JSON.parse(params[:body])['state']
          expected_state = @commit.ready? ? 'SUCCESSFUL' : 'INPROGRESS'
          expect(commit_state).to eql(expected_state)
          @commit.update_column :ready, !@commit.ready
        end.exactly(StashWebhookHelper::DEFAULT_NUM_TIMES).times
        subject.perform(@commit.id)
      end

      it "doesnt send anything if no stash_webhook_url is defined on the project" do
        expect(@commit.project.stash_webhook_url).to be_blank
        expect(HTTParty).not_to receive(:post)
        subject.perform(@commit.id)
      end

      it "raises a Project::NotLinkedToAGitRepositoryError if project doesn't have a repository_url" do
        @commit.project.update! repository_url: nil
        expect(HTTParty).not_to receive(:post)
        expect { subject.perform(@commit.id) }.to raise_error(Project::NotLinkedToAGitRepositoryError)
      end
    end

    context "on_create" do
      it "sends an http request to the project stash_webhook_url when a commit is first created" do
        @commit = FactoryGirl.build(:commit, ready: false, loading: true)
        @url = "http://www.example.com"
        @commit.project.stash_webhook_url = @url
        @commit.project.save!

        expect(HTTParty).to receive(:post).with("#{@url}/#{@commit.revision}", hash_including(body: {
            key: 'SHUTTLE',
            name: "SHUTTLE-#{@commit.revision_prefix}",
            url: project_commit_url(@commit.project,
                                    @commit,
                                    host: Shuttle::Configuration.app.default_url_options.host,
                                    port: Shuttle::Configuration.app.default_url_options['port'],
                                    protocol: Shuttle::Configuration.app.default_url_options['protocol'] || 'http'),
            state: 'INPROGRESS',
            description: 'Currently loading',
        }.to_json))
        @commit.save!
      end
    end
  end

  context "on_update" do
    before(:each) do
      @commit = FactoryGirl.build(:commit, ready: false, loading: true)
      @url = "http://www.example.com"
      @commit.project.stash_webhook_url = @url
      @commit.project.save!
      @commit.save!
    end

    it "sends an request when the commit loading state changes" do
      expect(HTTParty).to receive(:post).with("#{@url}/#{@commit.revision}", hash_including(body: {
          key: 'SHUTTLE',
          name: "SHUTTLE-#{@commit.revision_prefix}",
          url: project_commit_url(@commit.project,
                                  @commit,
                                  host: Shuttle::Configuration.app.default_url_options.host,
                                  port: Shuttle::Configuration.app.default_url_options['port'],
                                  protocol: Shuttle::Configuration.app.default_url_options['protocol'] || 'http'),
          state: 'INPROGRESS',
          description: 'Currently translating',
      }.to_json))

      @commit.loading = false
      # force commit not to be ready
      @commit.keys << FactoryGirl.create(:key, project: @commit.project)
      FactoryGirl.create :translation, key: @commit.keys.first, copy: nil
      @commit.save!
    end

    it "sends an request when the commit ready state changes" do
      expect(HTTParty).to receive(:post).with("#{@url}/#{@commit.revision}", hash_including(body: {
          key: 'SHUTTLE',
          name: "SHUTTLE-#{@commit.revision_prefix}",
          url: project_commit_url(@commit.project,
                                  @commit,
                                  host: Shuttle::Configuration.app.default_url_options.host,
                                  port: Shuttle::Configuration.app.default_url_options['port'],
                                  protocol: Shuttle::Configuration.app.default_url_options['protocol'] || 'http'),
          state: 'SUCCESSFUL',
          description: 'Translations completed',
      }.to_json))
      @commit.loading = false
      @commit.ready = true # redundant since CSR will do this anyway
      @commit.save!
    end
  end
end
