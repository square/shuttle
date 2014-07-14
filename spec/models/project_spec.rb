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

describe Project do
  describe '[CRUD]' do
    it "creates a valid project even if repository_url is nil" do
      project = Project.create(name: "Project without a repository_url")
      expect(project).to be_valid
      expect(project).to be_persisted
    end

    it "creates a valid project even if repository_url is empty" do
      project = Project.create(name: "Project with an empty repository_url", repository_url: "")
      expect(project).to be_valid
      expect(project).to be_persisted
    end

    it "sets repository_url to nil if it's empty" do
      project = Project.create(name: "Project with an empty repository_url", repository_url: "")
      expect(project.repository_url).to be_nil
    end
  end

  describe '#repo' do
    it "should check out the repository and return a Repository object" do
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      repo = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git").repo
      expect(repo).to be_kind_of(Git::Base)
      expect(repo.index).to be_nil # should be bare
      expect(repo.repo.path).to eql(Rails.root.join('tmp', 'repos', '55bc7a5f8df17ec2adbf954a4624ea152c3992d9.git').to_s)
    end
  end

  describe "#commit!" do
    before(:all) { @project = FactoryGirl.create(:project) }

    before :each do
      @repo = double('Git::Repo')
      # for GitObjectField checking
      allow_any_instance_of(Project).to receive(:repo).and_return(double('Git::Repo', object: double('Git::Object::Commit', :commit? => true)))
      # for commit! creation
      allow(@project).to receive(:repo).and_yield(@repo)
      @commit_obj = double('Git::Object::Commit',
                           sha:     'a4b6dd88498817d4947730c7964a1a14c8f13d91',
                           message: 'foo',
                           author:  double('Git::Author', name: "Sancho Sample", email: 'sancho@example.com', date: Time.now))
      allow_any_instance_of(Commit).to receive(:import_strings)
      allow_any_instance_of(Commit).to receive(:commit).and_return(@commit_obj)
    end

    it "should return an existing commit" do
      commit = FactoryGirl.create(:commit, project: @project, revision: 'a4b6dd88498817d4947730c7964a1a14c8f13d91')
      allow(@repo).to receive(:fetch)
      expect(@repo).to receive(:object).with('abc123').and_return(@commit_obj)
      expect(@project.commit!('abc123')).to eql(commit)
    end

    it "should create a new commit" do
      allow(@repo).to receive(:fetch)
      expect(@repo).to receive(:object).with('abc123').and_return(@commit_obj)
      commit = @project.commit!('abc123')
      expect(commit).to be_kind_of(Commit)
      expect(commit.revision).to eql('a4b6dd88498817d4947730c7964a1a14c8f13d91')
    end

    it "should fetch the repo and return a commit if the rev is unknown" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').and_return(nil, @commit_obj)
      commit = @project.commit!('abc123')
      expect(commit).to be_kind_of(Commit)
      expect(commit.revision).to eql('a4b6dd88498817d4947730c7964a1a14c8f13d91')
    end

    it "should raise an exception if the rev is still unknown after fetching" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').and_return(nil, nil)
      expect { @project.commit!('abc123') }.to raise_error(Git::CommitNotFoundError)
    end
  end

  describe "#pending_translations" do
    before :all do
      @project     = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @key1        = FactoryGirl.create(:key, project: @project)
      @key2        = FactoryGirl.create(:key, project: @project)
      @herring_key = FactoryGirl.create(:key)
    end

    it "should return the number of pending translations" do
      FactoryGirl.create :translation, key: @key1, copy: nil, rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: @key2, copy: nil, rfc5646_locale: 'fr-CA'
      # red herring
      FactoryGirl.create :translation, key: @herring_key, copy: nil, rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), copy: nil, rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), copy: "foo", rfc5646_locale: 'fr-CA'

      expect(@project.pending_translations(Locale.from_rfc5646('fr-CA'))).to eql(2)
    end

    it "should use the project's base locale by default" do
      FactoryGirl.create :translation, key: @key1, copy: nil, rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: @key2, copy: nil, rfc5646_locale: 'en-US'
      # red herrings
      FactoryGirl.create :translation, key: @herring_key, copy: nil, rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), copy: nil, rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), copy: "foo", rfc5646_locale: 'en-US'

      expect(@project.pending_translations).to eql(2)
    end
  end

  describe "#pending_reviews" do
    before :all do
      @project     = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @key1        = FactoryGirl.create(:key, project: @project)
      @key2        = FactoryGirl.create(:key, project: @project)
      @herring_key = FactoryGirl.create(:key)
    end

    it "should return the number of translations pending review" do
      FactoryGirl.create :translation, key: @key1, approved: nil, copy: 'foo', rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: @key2, approved: nil, copy: 'foo', rfc5646_locale: 'fr-CA'
      # red herrings
      FactoryGirl.create :translation, key: @herring_key, approved: nil, copy: 'foo', rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: @key1, approved: nil, copy: 'foo', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), approved: nil, copy: nil, rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), approved: false, copy: "foo", rfc5646_locale: 'fr-CA'

      expect(@project.pending_reviews(Locale.from_rfc5646('fr-CA'))).to eql(2)
    end

    it "should use the project's base locale by default" do
      FactoryGirl.create :translation, key: @key1, approved: nil, copy: 'foo', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: @key2, approved: nil, copy: 'foo', rfc5646_locale: 'en-US'
      # red herrings
      FactoryGirl.create :translation, key: @herring_key, approved: nil, copy: 'foo', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), approved: nil, copy: 'foo', rfc5646_locale: 'fr-CA'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), approved: nil, copy: nil, rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: FactoryGirl.create(:key, project: @project), approved: false, copy: "foo", rfc5646_locale: 'en-US'

      expect(@project.pending_reviews).to eql(2)
    end
  end

  describe "#find_or_fetch_git_object" do
    before :each do
      @project = FactoryGirl.create(:project)
      @repo = double('Git::Repo')
      @git_obj = double('Git::Object', sha: 'abc123')
      allow(@project).to receive(:repo).and_yield(@repo)
    end

    it "finds the git object in repo without fetching when it's already in repo" do
      expect(@repo).to_not receive(:fetch)
      expect(@repo).to receive(:object).with('abc123').once.and_return(@git_obj)
      git_obj = @project.find_or_fetch_git_object('abc123')
      expect(git_obj).to eql(@git_obj)
      expect(git_obj.sha).to eql('abc123')
    end

    it "finds the git object in repo after fetching when it was not previously in the repo" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil, @git_obj)
      git_obj = @project.find_or_fetch_git_object('abc123')
      expect(git_obj).to eql(@git_obj)
      expect(git_obj.sha).to eql('abc123')
    end

    it "doesn't find the git object if it is not found in the local repo even after fetching" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil)
      git_obj = @project.find_or_fetch_git_object('abc123')
      expect(git_obj).to be_nil
    end
  end

  describe "#latest_commit" do
    before do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
    end

    it "should return nil when there are no commits" do
      expect(@project.commits).to be_empty
      expect(@project.latest_commit).to be_nil
    end

    it "should return the one with the most recent committed_at when there are commits" do
      commit = FactoryGirl.create(:commit, project: @project)
      expect(@project.latest_commit).to eq(commit)
    end
  end

  describe "#skip_key?" do
    before(:all) { @project = FactoryGirl.create(:project) }

    it "should return true if there is no matching key inclusion" do
      @project.update_attributes(key_exclusions:        [],
                                 key_inclusions:        %w(in*),
                                 key_locale_inclusions: {},
                                 key_locale_exclusions: {})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_true
      expect(@project.skip_key?('included', Locale.from_rfc5646('en-US'))).to be_false
    end

    it "should return true if there is a key exclusion" do
      @project.update_attributes(key_exclusions:        %w(*cl*),
                                 key_inclusions:        [],
                                 key_locale_inclusions: {},
                                 key_locale_exclusions: {})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_true
    end

    it "should return true if there is a locale key exclusion in the given locale" do
      @project.update_attributes(key_exclusions:        [],
                                 key_inclusions:        [],
                                 key_locale_exclusions: {'en-US' => %w(*cl*)},
                                 key_locale_inclusions: {})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_true
    end

    it "should return false if there is a locale key exclusion in a different locale" do
      @project.update_attributes(key_exclusions:        [],
                                 key_inclusions:        [],
                                 key_locale_inclusions: {},
                                 key_locale_exclusions: {'fr-FR' => %w(*cl*)})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_false
    end

    it "should return true if there no matching locale key inclusion in the given locale" do
      @project.update_attributes(key_exclusions:        [],
                                 key_inclusions:        [],
                                 key_locale_inclusions: {'en-US' => %w(in*)},
                                 key_locale_exclusions: {})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_true
    end

    it "should return false if there is no matching locale key inclusion in a different locale" do
      @project.update_attributes(key_exclusions:        [],
                                 key_inclusions:        [],
                                 key_locale_exclusions: {},
                                 key_locale_inclusions: {'fr-FR' => %w(in*)})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_false
    end

    it "should return false if there is no exclusion" do
      @project.update_attributes(key_exclusions:        %w(*cb*),
                                 key_inclusions:        [],
                                 key_locale_inclusions: {},
                                 key_locale_exclusions: {})

      expect(@project.skip_key?('excluded', Locale.from_rfc5646('en-US'))).to be_false
    end
  end

  describe "#skip_path?" do
    before(:all) { @project = FactoryGirl.create(:project) }

    it "should return true if there is no matching path inclusion" do
      @project.update_attributes(skip_paths:          [],
                                 only_paths:          %w(foo/),
                                 only_importer_paths: {},
                                 skip_importer_paths: {})

      expect(@project.skip_path?('bar/foo.txt', Importer::Ruby)).to be_true
      expect(@project.skip_path?('foo/bar.txt', Importer::Ruby)).to be_false
    end

    it "should return true if there is a path exclusion" do
      @project.update_attributes(skip_paths:          %w(foo/),
                                 only_paths:          [],
                                 only_importer_paths: {},
                                 skip_importer_paths: {})

      expect(@project.skip_path?('foo/bar.txt', Importer::Ruby)).to be_true
    end

    it "should return true if there is an importer path exclusion for the given importer" do
      @project.update_attributes(skip_paths:          [],
                                 only_paths:          [],
                                 skip_importer_paths: {'yaml' => %w(foo/)},
                                 only_importer_paths: {})

      expect(@project.skip_path?('foo/bar.txt', Importer::Yaml)).to be_true
    end

    it "should return false if there is an importer path exclusion for a different importer" do
      @project.update_attributes(skip_paths:          [],
                                 only_paths:          [],
                                 only_importer_paths: {},
                                 skip_importer_paths: {'yaml' => %w(foo/)})

      expect(@project.skip_path?('foo/bar.txt', Importer::Ruby)).to be_false
    end

    it "should return true if there no matching importer path inclusion for the given importer" do
      @project.update_attributes(skip_paths:          [],
                                 only_paths:          [],
                                 only_importer_paths: {'yaml' => %w(foo/)},
                                 skip_importer_paths: {})

      expect(@project.skip_path?('bar/foo.txt', Importer::Yaml)).to be_true
    end

    it "should return false if there is no matching importer path inclusion for a different importer" do
      @project.update_attributes(skip_paths:          [],
                                 only_paths:          [],
                                 skip_importer_paths: {},
                                 only_importer_paths: {'yaml' => %w(foo/)})

      expect(@project.skip_path?('bar/foo.txt', Importer::Ruby)).to be_false
    end

    it "should return false if there is no exclusion" do
      @project.update_attributes(skip_paths:          %w(foo/),
                                 only_paths:          [],
                                 only_importer_paths: {},
                                 skip_importer_paths: {})

      expect(@project.skip_path?('bar/foo.txt', Importer::Ruby)).to be_false
    end
  end

  describe "#skip_tree?" do
    context '[only paths]' do
      before :all do
        @project = FactoryGirl.create(:project,
                                      only_paths:          %w(only/path),
                                      only_importer_paths: {'foo' => %w(importeronly/path)})
      end

      it "should return false if given an only path" do
        expect(@project.skip_tree?('/only/path')).to be_false
      end

      it "should return false if given the parent of an only path" do
        expect(@project.skip_tree?('/only')).to be_false
      end

      it "should return false if given the child of an only path" do
        expect(@project.skip_tree?('/only/path/child')).to be_false
      end

      it "should return false if given an importer-specific only path" do
        expect(@project.skip_tree?('/importeronly/path')).to be_false
      end

      it "should return false if given the parent of an importer-specific only path" do
        expect(@project.skip_tree?('/importeronly')).to be_false
      end

      it "should return false if given the child of an importer-specific only path" do
        expect(@project.skip_tree?('/importeronly/path/child')).to be_false
      end

      it "should return true if true if a path that's not related to the only paths" do
        expect(@project.skip_tree?('/foo/bar')).to be_true
      end
    end

    context '[skip paths]' do
      before :all do
        @project = FactoryGirl.create(:project,
                                      skip_paths:          %w(skip/path),
                                      skip_importer_paths: {'foo' => %w(importerskip/path)})
      end
      it "should return true if given a skip path" do
        expect(@project.skip_tree?('/skip/path')).to be_true
      end

      it "should return false if given the parent of a skip path" do
        expect(@project.skip_tree?('/skip')).to be_false
      end

      it "should return true if given the child of a skip path" do
        expect(@project.skip_tree?('/skip/path/child')).to be_true
      end

      it "should return true if given an importer-specific skip path" do
        expect(@project.skip_tree?('/importerskip/path')).to be_true
      end

      it "should return false if given the parent of an importer-specific skip path" do
        expect(@project.skip_tree?('/importerskip')).to be_false
      end

      it "should return true if given the child of an importer-specific skip path" do
        expect(@project.skip_tree?('/importerskip/path/child')).to be_true
      end

      it "should return false if there are no applicable skip paths" do
        expect(@project.skip_tree?('/foo/bar')).to be_false
      end
    end
  end

  context "[hooks]" do
    it "should recalculate pending translations when the list of targeted locales is changed" do
      project = FactoryGirl.create(:project,
                                   targeted_rfc5646_locales: {'en' => true, 'fr' => true})
      key1    = FactoryGirl.create(:key, project: project)
      key2    = FactoryGirl.create(:key, project: project)

      trans1_en = FactoryGirl.create(:translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      trans1_fr = FactoryGirl.create(:translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'fr')
      trans2_en = FactoryGirl.create(:translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      trans2_fr = FactoryGirl.create(:translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'fr')

      project.targeted_rfc5646_locales = project.targeted_rfc5646_locales.merge('de' => false)
      project.save!

      expect(key1.translations.count).to eql(3)
      expect(key2.translations.count).to eql(3)

      expect(key1.translations.where(rfc5646_locale: 'de').exists?).to be_true
      expect(key2.translations.where(rfc5646_locale: 'de').exists?).to be_true
    end

    it "should recalculate commit readiness when required locales are added or removed" do
      project = FactoryGirl.create(:project,
                                   targeted_rfc5646_locales: {'en' => true, 'fr' => false})
      key1    = FactoryGirl.create(:key, project: project)
      key2    = FactoryGirl.create(:key, project: project)

      trans1_en = FactoryGirl.create(:translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'en', translated: true, approved: true)
      trans1_fr = FactoryGirl.create(:translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', translated: true, approved: true)
      trans2_en = FactoryGirl.create(:translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'en', translated: true, approved: true)
      trans2_fr = FactoryGirl.create(:translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', translated: true, approved: false)

      commit      = FactoryGirl.create(:commit, project: project)
      commit.keys = [key1, key2]

      expect(key1).to be_ready
      expect(key2).to be_ready
      expect(commit).to be_ready

      project.targeted_rfc5646_locales = {'en' => true, 'fr' => true}
      project.save!

      expect(key1.reload).to be_ready
      expect(key2.reload).not_to be_ready
      expect(commit.reload).not_to be_ready
    end

    context "[add_or_remove_pending_translations]" do
      around { |tests| Sidekiq::Testing.fake!(&tests) }

      before(:all) do
        @project = FactoryGirl.create(:project, name: "this is a test project",
                                                 targeted_rfc5646_locales: {'en' => true},
                                                 key_exclusions: [],
                                                 key_inclusions: [],
                                                 key_locale_exclusions: {},
                                                 key_locale_inclusions: {} )
      end

      it "calls ProjectTranslationAdder when targeted_rfc5646_locales changes" do
        @project.targeted_rfc5646_locales = {'fr' => true}
        expect(ProjectTranslationAdder).to receive(:perform_once)
        @project.save!
      end

      it "calls ProjectTranslationAdder when key_exclusions changes" do
        @project.key_exclusions = %w{skip_me}
        expect(ProjectTranslationAdder).to receive(:perform_once)
        @project.save!
      end

      it "calls ProjectTranslationAdder when key_inclusions changes" do
        @project.key_inclusions = %w{include_me}
        expect(ProjectTranslationAdder).to receive(:perform_once)
        @project.save!
      end

      it "calls ProjectTranslationAdder when key_locale_exclusions changes" do
        @project.key_locale_exclusions = {'fr-FR' => %w(*cl*)}
        expect(ProjectTranslationAdder).to receive(:perform_once)
        @project.save!
      end

      it "calls ProjectTranslationAdder when key_locale_inclusions changes" do
        @project.key_locale_inclusions = {'fr-FR' => %w(*cl*)}
        expect(ProjectTranslationAdder).to receive(:perform_once)
        @project.save!
      end

      it "doesn't call ProjectTranslationAdder fields like name, watched_branches, stash_webhook_url change" do
        @project.name = "new name"
        @project.watched_branches = ['newbranch']
        @project.stash_webhook_url = "https://example.com"
        expect(ProjectTranslationAdder).to_not receive(:perform_once)
        @project.save!
      end

      it "doesn't call ProjectTranslationAdder when a project is created, even if it has targeted_rfc5646_locales and key_exclusions" do
        expect(ProjectTranslationAdder).to_not receive(:perform_once)
        FactoryGirl.create(:project, targeted_rfc5646_locales: {'es' => true}, key_exclusions: %w{skip_me})
      end
    end
  end

  describe '#update_touchdown_branch' do
    before :each do
      Project.delete_all
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      # delete an existing translated branch, if it exists
      system 'git', 'push', @project.repository_url, ':refs/heads/translated'
    end

    it "should do nothing unless watched_branches and touchdown_branch are set" do
      @project.watched_branches = []
      @project.touchdown_branch = nil

      @project.update_touchdown_branch

      expect(`git --git-dir=#{Shellwords.escape @project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
    end

    it "should advance the touchdown branch to the most recently translated watched branch commit" do
      @project.watched_branches = %w(master)
      @project.touchdown_branch = 'translated'

      c = @project.commit!('d82287c47388278d54433cfb2383c7ad496d9827')
      c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
      CommitStatsRecalculator.new.perform(c.id)
      expect(c.reload).to be_ready

      @project.update_touchdown_branch

      expect(`git --git-dir=#{Shellwords.escape @project.repository_url} rev-parse translated`.chomp).
          to eql('d82287c47388278d54433cfb2383c7ad496d9827')
    end

    it "should log an error if updating the touchdown branch takes longer than 1 minute" do
      @project.watched_branches = %w(master)
      @project.touchdown_branch = 'translated'

      allow(@project).to receive('system').and_raise(Timeout::Error)

      c = @project.commit!('d82287c47388278d54433cfb2383c7ad496d9827')
      c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
      CommitStatsRecalculator.new.perform(c.id)

      expect(c.reload).to be_ready
      expect(Rails.logger).to receive(:error).with("[Project#update_touchdown_branch] Timed out on updating touchdown branch for #{@project.inspect}")

      @project.update_touchdown_branch
    end

    it "should do nothing if none of the commits in the watched branch are translated" do
      @project.watched_branches = %w(master)
      @project.touchdown_branch = 'translated'

      c = @project.commit!('d82287c47388278d54433cfb2383c7ad496d9827')
      expect(c).not_to be_ready

      @project.update_touchdown_branch

      expect(`git --git-dir=#{Shellwords.escape @project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
    end

    it "should gracefully exit if the first watched branch doesn't exist" do
      @project.watched_branches = %w(nonexistent)
      @project.touchdown_branch = 'translated'

      c = @project.commit!('d82287c47388278d54433cfb2383c7ad496d9827')
      c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
      CommitStatsRecalculator.new.perform(c.id)
      expect(c.reload).to be_ready

      expect { @project.update_touchdown_branch }.not_to raise_error
    end
  end
end
