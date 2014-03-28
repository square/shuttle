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

      it "sends an http request to the project stash_webhook_url if one is defined" do
        url = "http://www.example.com"
        @commit.project.stash_webhook_url = url
        @commit.project.save!
        expect(HTTParty).to receive(:post).with(
                                "#{url}/#{@commit.revision}",
                                anything()
                            )
        subject.perform(@commit.id)
      end

      it "doesnt send anything if no stash_webhook_url is defined on the project" do
        expect(@commit.project.stash_webhook_url).to be_blank
        expect(HTTParty).not_to receive(:post)
        subject.perform(@commit.id)
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
            name: "SHUTTLE-#{@commit.revision[0..6]}",
            url: project_commit_url(@commit.project,
                                    @commit,
                                    host: Shuttle::Configuration.worker.default_url_options.host,
                                    port: Shuttle::Configuration.worker.default_url_options['port'] || 80),
            state: 'INPROGRESS',
            description: 'Currently loading',
        }))
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
          name: "SHUTTLE-#{@commit.revision[0..6]}",
          url: project_commit_url(@commit.project,
                                  @commit,
                                  host: Shuttle::Configuration.worker.default_url_options.host,
                                  port: Shuttle::Configuration.worker.default_url_options['port'] || 80),
          state: 'INPROGRESS',
          description: 'Currently translating',
      }))

      @commit.loading = false
      @commit.save!
    end

    it "sends an request when the commit ready state changes" do
      expect(HTTParty).to receive(:post).with("#{@url}/#{@commit.revision}", hash_including(body: {
          key: 'SHUTTLE',
          name: "SHUTTLE-#{@commit.revision[0..6]}",
          url: project_commit_url(@commit.project,
                                  @commit,
                                  host: Shuttle::Configuration.worker.default_url_options.host,
                                  port: Shuttle::Configuration.worker.default_url_options['port'] || 80),
          state: 'SUCCESSFUL',
          description: 'Translations completed',
      }))
      @commit.loading = false
      @commit.ready = true
      @commit.save!
    end
  end
end
