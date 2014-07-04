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

describe Commit do
  context "[mailing import errors]" do

    def commit_and_expect_import_errors(project, revision, user)
      ActionMailer::Base.deliveries.clear
      commit  = project.commit!(revision, other_fields: {user: user}).reload

      expect(ActionMailer::Base.deliveries.map(&:subject)).to include("[Shuttle] Error(s) occurred during the import")
      expect(commit.import_errors.sort).to eql([["/ember-broken/en-US.js", "Unexpected identifier at <eval>:2:12"],
                                                ["/config/locales/ruby/broken.yml", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1"],
                                                ["/ember-broken/en-US.coffee", "[stdin]:2:5: error: unexpected this this is some invalid javascript code ^^^^"]].sort)
      expect(Blob.where(errored: true).count).to eql(2) # en-US.coffee and en-US.js files have the same contents, so they map to the same blob
    end

    it "should email if commit has import errors after submitting twice" do
      Blob.delete_all
      user = FactoryGirl.create(:user)
      project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)

      commit_and_expect_import_errors(project, 'a82cf69f11618883e534189dea61f234da914462', user)
      expect(Blob.count).to eql(2) # see above

      commit_and_expect_import_errors(project, 'HEAD', user)
      expect(Blob.count).to eql(3)  # see above
    end
  end


  context "[pinging webhooks]" do
    around do |example|
      Sidekiq::Testing.fake!(&example)
    end

    context "[stash]" do
      context "[with a stash_webhook_url]" do
        before(:each) do
          @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, stash_webhook_url: "http://example.com")
          @commit = FactoryGirl.create(:commit, project: @project, ready: false, loading: false)
        end

        it "enqueues a StashWebhookPinger job when a commit is created" do
          commit = FactoryGirl.build(:commit, project: @project)
          expect(StashWebhookPinger).to receive(:perform_once)
          commit.save!
        end

        it "enqueues a StashWebhookPinger job when a commit becomes ready" do
          @commit.ready = true
          expect(StashWebhookPinger).to receive(:perform_once)
          @commit.save!
        end

        it "enqueues a StashWebhookPinger job when a commit becomes not-ready" do
          @commit.update!(ready: true)
          @commit.ready = false
          expect(StashWebhookPinger).to receive(:perform_once)
          @commit.save!
        end

        it "enqueues a StashWebhookPinger job when a commit finishes loading" do
          @commit.update!(loading: true)
          @commit.loading = false
          expect(StashWebhookPinger).to receive(:perform_once)
          @commit.save!
        end

        it "enqueues a StashWebhookPinger job when a commit starts loading" do
          @commit.loading = true
          expect(StashWebhookPinger).to receive(:perform_once)
          @commit.save!
        end

        it "does not enqueue a StashWebhookPinger job when a commit is updated without changing its ready and loading fields" do
          @commit.message = "some message"
          expect(StashWebhookPinger).to_not receive(:perform_once)
          @commit.save!
        end
      end

      context "[without a stash_webhook_url]" do
        before(:each) do
          @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, stash_webhook_url: nil)
          @commit = FactoryGirl.create(:commit, project: @project, ready: false, loading: false)
        end

        it "does not enqueue a StashWebhookPinger job when a commit is created" do
          commit = FactoryGirl.build(:commit, project: @project)
          expect(StashWebhookPinger).to_not receive(:perform_once)
          commit.save!
        end

        it "does not enqueue a StashWebhookPinger job when a commit becomes ready" do
          @commit.ready = true
          expect(StashWebhookPinger).to_not receive(:perform_once)
          @commit.save!
        end
      end
    end

    context "[github]" do
      context "[with a github_webhook_url]" do
        before(:each) do
          @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, github_webhook_url: "http://example.com")
          @commit = FactoryGirl.create(:commit, project: @project, ready: false, loading: false)
        end

        it "does not enqueue a GithubWebhookPinger job when a commit is created" do
          @commit = FactoryGirl.build(:commit, project: @project, ready: true)
          expect(GithubWebhookPinger).to_not receive(:perform_once)
          @commit.save!
        end

        it "enqueues a GithubWebhookPinger job when a commit becomes ready" do
          @commit.ready = true
          expect(GithubWebhookPinger).to receive(:perform_once)
          @commit.save!
        end

        it "doesn't enqueue a GithubWebhookPinger job when a commit becomes not-ready" do
          @commit.update!(ready: true)
          @commit.ready = false
          expect(GithubWebhookPinger).to_not receive(:perform_once)
          @commit.save!
        end

        it "doesn't enqueue a GithubWebhookPinger when a commit is updated without changing its ready field" do
          @commit.message = "some message"
          expect(GithubWebhookPinger).to_not receive(:perform_once)
          @commit.save!
        end
      end

      context "[without a github_webhook_url]" do
        before(:each) do
          @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, github_webhook_url: nil)
          @commit = FactoryGirl.create(:commit, project: @project, ready: false, loading: false)
        end

        it "does not enqueue a GithubWebhookPinger job when a commit's ready field changes" do
          @commit.ready = true
          expect(GithubWebhookPinger).to_not receive(:perform_once)
          @commit.save!
        end
      end
    end
  end
end
