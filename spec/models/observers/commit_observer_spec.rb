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

describe CommitObserver do
  context "[mail hooks]" do
    context "[on loading_finished]" do
      context "[with import errors]" do
        def commit_and_expect_import_errors(project, revision, user)
          ActionMailer::Base.deliveries.clear
          commit  = project.commit!(revision, other_fields: {user: user}).reload

          expect(ActionMailer::Base.deliveries.map(&:subject)).to include("[Shuttle] Error(s) occurred during the import")
          expect(commit.import_errors.sort).to eql([["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                                                    ["Psych::SyntaxError", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1 (in /config/locales/ruby/broken.yml)"],
                                                    ["V8::Error", "Unexpected identifier at <eval>:2:12 (in /ember-broken/en-US.js)"]].sort)

          expect(Blob.where(errored: true).count).to eql(3)
        end

        it "should email if commit has import errors after submitting twice" do
          user = FactoryGirl.create(:user)
          project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)

          commit_and_expect_import_errors(project, 'a82cf69f11618883e534189dea61f234da914462', user)
          expect(Blob.count).to eql(3)

          commit_and_expect_import_errors(project, 'c04aeaa2bd9d8ff21c12eda2cb56e8622abb4727', user) # this is (almost) an empty commit
          expect(Blob.count).to eql(4)
        end
      end

      context "[without import errors]" do
        it "sends an email to the translators and cc's the user when loading changes to false from true if not all keys are translated yet" do
          @commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil, user: FactoryGirl.create(:user))
          @key = FactoryGirl.create(:key, project: @commit.project, ready: false)
          @commit.keys << @key

          ActionMailer::Base.deliveries.clear
          @commit.update! loading: false

          expect(ActionMailer::Base.deliveries.size).to eql(1)
          email = ActionMailer::Base.deliveries.first
          expect(email.to).to eql([Shuttle::Configuration.app.mailer.translators_list])
          expect(email.cc).to eql([@commit.user.email])
          expect(email.subject).to eql('[Shuttle] New commit ready for translation')
          expect(email.body.to_s).to include("http://test.host/?project_id=#{@commit.project_id}&status=uncompleted")
        end

        it "sends one email to the translators when loading changes to false if the commit has no user if not all keys are translated yet" do
          @commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil)
          @key = FactoryGirl.create(:key, project: @commit.project, ready: false)
          @commit.keys << @key

          ActionMailer::Base.deliveries.clear
          @commit.update! loading: false

          expect(ActionMailer::Base.deliveries.size).to eql(1)
          email = ActionMailer::Base.deliveries.first
          expect(email.to).to eql([Shuttle::Configuration.app.mailer.translators_list])
          expect(email.subject).to eql('[Shuttle] New commit ready for translation')
          expect(email.body.to_s).to include("http://test.host/?project_id=#{@commit.project_id}&status=uncompleted")
        end

        it "does not send an email if the commit was previously ready" do
          @commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil, user: FactoryGirl.create(:user), completed_at: 1.day.ago)
          ActionMailer::Base.deliveries.clear
          @commit.loading = false
          @commit.save!
          expect(ActionMailer::Base.deliveries.size).to be_zero
        end

        it "does not send an email when a new commit is loaded if all keys are already translated" do
          commit = FactoryGirl.create(:commit, loading: true)
          key = FactoryGirl.create(:key, project: commit.project, ready: true)
          commit.keys << key
          ActionMailer::Base.deliveries.clear
          commit.update! loading: false
          expect(ActionMailer::Base.deliveries.count).to eql(0)
        end
      end
    end

    context "[on became_ready]" do
      it "sends an email when ready changes to true from false" do
        @commit = FactoryGirl.create(:commit, ready: false, user: FactoryGirl.create(:user, email: "author@xample.com"))

        @commit.project.key_inclusions += %w(inc_key_1 inc_key_2)
        @commit.project.key_exclusions += %w(exc_key_1 exc_key_2 exc_key_3)

        @commit.project.key_locale_inclusions = {"fr" => ["fr_exc_key_1", "fr_exc_key_2", "fr_exc_key_3"], "aa" => ["aa_exc_key_1", "aa_exc_key_2"]}
        @commit.project.key_locale_exclusions = {"ja" => ["ja_inc_key_1", "ja_inc_key_2", "ja_inc_key_3"]}

        @commit.project.only_paths += %w(only_path_1 only_path_2 only_path_1)
        @commit.project.skip_paths += %w(skip_path_1 skip_path_2)

        @commit.project.skip_importer_paths = {"Android XML" => ["an_skip_key_1", "an_skip_key_2", "an_skip_key_3"]}
        @commit.project.only_importer_paths = {"Ember.js" => ["em_only_key_1", "em_only_key_2", "em_only_key_3"], "ERb File" => ["erb_only_key_1", "erb_only_key_2"]}

        ActionMailer::Base.deliveries.clear
        expect(@commit.reload).to_not be_ready
        @commit.update! ready: true
        expect(@commit).to be_ready

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first

        expect(email.to).to eql(["author@xample.com"])
        expect(email.subject).to eql('[Shuttle] Finished translation of commit')
        expect(email.body.to_s).to include(@commit.revision.to_s)

        @commit.project.key_inclusions.each { |key| expect(email.body.to_s).to include(key) }
        @commit.project.key_exclusions.each { |key| expect(email.body.to_s).to include(key) }

        @commit.project.key_locale_inclusions.each_key do |locale|
          expect(email.body.to_s).to include(locale + ":")
          @commit.project.key_locale_inclusions[locale].each { |key| expect(email.body.to_s).to include(key) }
        end
        @commit.project.key_locale_exclusions.each_key do |locale|
          expect(email.body.to_s).to include(locale + ":")
          @commit.project.key_locale_exclusions[locale].each { |key| expect(email.body.to_s).to include(key) }
        end

        @commit.project.only_paths.each { |key| expect(email.body.to_s).to include(key) }
        @commit.project.skip_paths.each { |key| expect(email.body.to_s).to include(key) }

        @commit.project.skip_importer_paths.each_key do |path|
          expect(email.body.to_s).to include(path + ":")
          @commit.project.skip_importer_paths[path].each { |key| expect(email.body.to_s).to include(key) }
        end
        @commit.project.only_importer_paths.each_key do |path|
          expect(email.body.to_s).to include(path + ":")
          @commit.project.only_importer_paths[path].each { |key| expect(email.body.to_s).to include(key) }
        end
      end

      it "should not send an email when ready changes to true from false if the commit has no user or the user has no email" do
        @commit = FactoryGirl.create(:commit, ready: false)
        ActionMailer::Base.deliveries.clear
        @commit.ready = true
        @commit.save!
        expect(ActionMailer::Base.deliveries).to be_empty
      end
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

      context "[without a repository_url]" do
        it "does not enqueue a StashWebhookPinger job when a commit is created or when it becomes ready" do
          expect(StashWebhookPinger).to_not receive(:perform_once)
          project = FactoryGirl.create(:project, repository_url: nil, stash_webhook_url: "http://example.com")
          commit = FactoryGirl.create(:commit, project: project, ready: false, loading: false)
          commit.update! ready: true
          commit.save!
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

      context "[without a repository_url]" do
        it "does not enqueue a GithubWebhookPinger job when a commit is created or when it becomes ready" do
          expect(GithubWebhookPinger).to_not receive(:perform_once)
          project = FactoryGirl.create(:project, repository_url: nil, github_webhook_url: "http://example.com")
          commit = FactoryGirl.create(:commit, project: project, ready: false, loading: false)
          commit.update! ready: true
          commit.save!
        end
      end
    end
  end

  describe "#just_became_ready?" do
    [[false, true, true],
     [true, true, false],
     [false, false, false],
     [true, false, false]].each do |before, after, result|
      it "returns #{result} if ready went from #{before} false to #{after}" do
        commit = FactoryGirl.create(:commit)
        commit.update! ready: before
        commit.reload.update! ready: after
        expect(CommitObserver.instance.send(:just_became_ready?, commit)).to eql(result)
      end
    end
  end

  describe "#just_finished_loading?" do
    [[false, true, false],
     [true, true, false],
     [false, false, false],
     [true, false, true]].each do |before, after, result|
      it "returns #{result} if loading went from #{before} false to #{after}" do
        commit = FactoryGirl.create(:commit)
        commit.update! loading: before
        commit.reload.update! loading: after
        expect(CommitObserver.instance.send(:just_finished_loading?, commit)).to eql(result)
      end
    end
  end
end
