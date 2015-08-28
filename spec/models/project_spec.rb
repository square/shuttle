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
  it_behaves_like "CommonLocaleLogic"

  describe '[CRUD]' do
    it "creates a valid project even if repository_url is nil" do
      project = Project.create(name: "Project without a repository_url", repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
      expect(project).to be_valid
      expect(project).to be_persisted
    end

    it "creates a valid project even if repository_url is empty" do
      project = Project.create(name: "Project with an empty repository_url", repository_url: "", base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
      expect(project).to be_valid
      expect(project).to be_persisted
    end

    it "sets repository_url to nil if it's empty" do
      project = Project.create(name: "Project with an empty repository_url", repository_url: "", base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
      expect(project.repository_url).to be_nil
    end

    it "doesn't create a project if base_rfc5646_locale is nil" do
      project = Project.create(name: "test", repository_url: nil, base_rfc5646_locale: nil, targeted_rfc5646_locales: {'fr' => true})
      expect(project).to_not be_persisted
      expect(project.errors.full_messages).to eql(["source locale can’t be blank"])
    end

    it "doesn't create a project if targeted_rfc5646_locales is nil" do
      project = Project.create(name: "test", base_rfc5646_locale: nil, targeted_rfc5646_locales: {'fr' => true})
      expect(project).to_not be_persisted
      expect(project.errors.full_messages).to eql(["source locale can’t be blank"])
    end

    it "doesn't create a project if targeted_rfc5646_locales is empty hash" do
      project = Project.create(name: "test", base_rfc5646_locale: 'en', targeted_rfc5646_locales: {})
      expect(project).to_not be_persisted
      expect(project.errors.full_messages).to eql(["targeted localizations can’t be blank"])
    end
  end

  describe "#repo" do
    it "should check out the repository and return a Repository object" do
      repo = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git").repo
      expect(repo).to be_kind_of(Git::Base)
      expect(repo.index).to be_nil # should be bare
      expect(repo.repo.path).to eql(Rails.root.join('tmp', 'repos', '55bc7a5f8df17ec2adbf954a4624ea152c3992d9.git').to_s)
    end

    it "should yield the Repository object if a block is passed" do
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      expect { |b| project.repo(&b) }.to yield_with_args(kind_of(Git::Base))
    end

    it "should obtain a lock on the Repository object if a block is passed" do
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      # To ensure that the repo already exists and doesn't need to synchronize
      project.repo
      expect_any_instance_of(FileMutex).to receive(:synchronize)
      project.repo {}
    end

    it "raises Project::NotLinkedToAGitRepositoryError when repo is called if repository_url is nil" do
      project = Project.create(name: "test", repository_url: nil)
      expect { project.repo }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end
  end

  describe "#working_repo" do
    it "should check out the repository and return a Repository object" do
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      working_repo = project.working_repo
      expect(working_repo).to be_kind_of(Git::Base)
      expect(working_repo.index).to_not be_nil # should not be bare
      expect(working_repo.dir.path).to eql(Rails.root.join('tmp', 'working_repos', '55bc7a5f8df17ec2adbf954a4624ea152c3992d9').to_s)
    end

    it "should yield the Repository object if a block is passed" do
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      expect { |b| project.working_repo(&b) }.to yield_with_args(kind_of(Git::Base))
    end

    it "should obtain a lock on the Repository object if a block is passed" do
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      # To ensure that the working_repo already exists and doesn't need to synchronize
      project.working_repo
      expect_any_instance_of(FileMutex).to receive(:synchronize)
      project.working_repo {}
    end

    it "raises Project::NotLinkedToAGitRepositoryError when repo is called if repository_url is nil" do
      project = Project.create(name: "test", repository_url: nil)
      expect { project.working_repo }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end
  end

  describe "#commit!" do
    before :each do
      @project = FactoryGirl.create(:project)
      @repo = double('Git::Repo')
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

  describe "#translations_adder_and_remover_batch" do
    it "creates a new batch, saves its id, and runs ProjectTranslationsAdderAndRemover::Finisher on success and sets description" do
      project = FactoryGirl.create(:project)

      ProjectTranslationsAdderAndRemover::Finisher.any_instance.should_receive(:on_success).with(instance_of(Sidekiq::Batch::Status), 'project_id' => project.id)
      batch = project.translations_adder_and_remover_batch.tap { |b| b.jobs {} }

      expect(batch).to be_an_instance_of(Sidekiq::Batch)
      expect(batch.description).to eql("Project Translations Adder And Remover #{project.id} (#{project.name})")
      expect(project.translations_adder_and_remover_batch_id).to eql(batch.bid)
    end
  end

  describe "#pending_translations" do
    before :each do
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
    before :each do
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

    it "raises Project::NotLinkedToAGitRepositoryError if project doesn't have a repository_url" do
      project = Project.create(name: "test")
      expect { project.find_or_fetch_git_object("any") }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end
  end

  describe "#latest_commit" do
    before :each do
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
    before(:each) { @project = FactoryGirl.create(:project) }

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
    before(:each) { @project = FactoryGirl.create(:project) }

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
      before :each do
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
      before :each do
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
                                   base_rfc5646_locale: 'en',
                                   targeted_rfc5646_locales: {'en' => true, 'fr' => true})
      key1    = FactoryGirl.create(:key, project: project)
      key2    = FactoryGirl.create(:key, project: project)
      commit      = FactoryGirl.create(:commit, project: project)
      commit.keys = [key1, key2]

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
                                   base_rfc5646_locale: 'en',
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
      commit.update_column :ready, true

      project.targeted_rfc5646_locales = {'en' => true, 'fr' => true}
      project.save!

      expect(key1.reload).to be_ready
      expect(key2.reload).not_to be_ready
      expect(commit.reload).not_to be_ready
    end

    context "[add_or_remove_pending_translations]" do
      around { |tests| Sidekiq::Testing.fake!(&tests) }

      context "[ProjectTranslationsAdderAndRemover]" do
        before :each do
          @project = FactoryGirl.create(:project, name: "this is a test project",
                                        targeted_rfc5646_locales: {'en' => true},
                                        key_exclusions: [],
                                        key_inclusions: [],
                                        key_locale_exclusions: {},
                                        key_locale_inclusions: {} )
        end

        it "calls ProjectTranslationsAdderAndRemover when targeted_rfc5646_locales changes" do
          @project.targeted_rfc5646_locales = {'fr' => true}
          expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once)
          @project.save!
        end

        it "calls ProjectTranslationsAdderAndRemover when key_exclusions changes" do
          @project.key_exclusions = %w{skip_me}
          expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once)
          @project.save!
        end

        it "calls ProjectTranslationsAdderAndRemover when key_inclusions changes" do
          @project.key_inclusions = %w{include_me}
          expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once)
          @project.save!
        end

        it "calls ProjectTranslationsAdderAndRemover when key_locale_exclusions changes" do
          @project.key_locale_exclusions = {'fr-FR' => %w(*cl*)}
          expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once)
          @project.save!
        end

        it "calls ProjectTranslationsAdderAndRemover when key_locale_inclusions changes" do
          @project.key_locale_inclusions = {'fr-FR' => %w(*cl*)}
          expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once)
          @project.save!
        end

        it "doesn't call ProjectTranslationsAdderAndRemover fields like name, watched_branches, stash_webhook_url change" do
          @project.name = "new name"
          @project.watched_branches = ['newbranch']
          @project.stash_webhook_url = "https://example.com"
          expect(ProjectTranslationsAdderAndRemover).to_not receive(:perform_once)
          @project.save!
        end

        it "doesn't call ProjectTranslationsAdderAndRemover when a project is created, even if it has targeted_rfc5646_locales and key_exclusions" do
          expect(ProjectTranslationsAdderAndRemover).to_not receive(:perform_once)
          FactoryGirl.create(:project, targeted_rfc5646_locales: {'es' => true}, key_exclusions: %w{skip_me})
        end

        it "doesn't call ProjectTranslationsAdderAndRemover when watched branches change if project is not git-specific" do
          @project.watched_branches = ['newbranch']
          expect(ProjectTranslationsAdderAndRemover).to_not receive(:perform_once)
          @project.save!
        end
      end
    end

    context "[create_api_token]" do
      it "sets a 240 character api token on create" do
        project = FactoryGirl.create(:project, name: "Test", api_token: '')
        expect(project.api_token).to be_present
        expect(project.api_token.length).to eql(240)
      end

      it "doesn't change the api_token on update" do
        project = FactoryGirl.create(:project, name: "Test")
        token = project.api_token
        project.update! name: "New test"
        expect(project.api_token).to eql(token)
      end
    end
  end

  context "[scopes]" do
    before :each do
      @project_with_repo =    FactoryGirl.create(:project, repository_url: "test")
      @project_without_repo = FactoryGirl.create(:project, repository_url: nil)
    end

    context "[scope = git]" do
      it "returns the projects which has a repository_url" do
        expect(Project.git.to_a).to eql([@project_with_repo])
      end
    end

    context "[scope = not_git]" do
      it "returns the projects which don't have a repository_url" do
        expect(Project.not_git.to_a).to eql([@project_without_repo])
      end
    end
  end

  describe "#repo_path" do
    it "returns nil if repository_url is not provided" do
      project = Project.create(name: "Project with an empty repository_url")
      expect(project.send :repo_path).to be_nil
    end

    it "returns correct repo path for a project with a non-empty repository_url" do
      expect(Project.create(name: "test", repository_url: "http://example.com").send :repo_path).to eql(Rails.root.join('tmp', 'repos', '89dce6a446a69d6b9bdc01ac75251e4c322bcdff.git'))
    end
  end

  describe "#repo_directory" do
    it "returns nil if repository_url is not provided" do
      expect(Project.create(name: "test").send :repo_directory).to be_nil
    end

    it "returns correct repo directory for a project with a non-empty repository_url" do
      project = Project.create(name: "Project with an non-empty repository_url", repository_url: "http://example.com")
      expect(project.send :repo_directory).to eql('89dce6a446a69d6b9bdc01ac75251e4c322bcdff.git')
    end
  end

  describe "#clone_repo" do
    it "raises Project::NotLinkedToAGitRepositoryError if repository_url is nil" do
      project = Project.create(name: "Project with an empty repository_url")
      expect(Git).to_not receive(:clone)
      expect { project.send :clone_repo }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end

    it "calls Git.clone once to clone the repo if repository_url exists" do
      project = Project.create(name: "Project with an non-empty repository_url", repository_url: "http://example.com")
      expect(Git).to receive(:clone).once.with(anything(), anything(), {path: Project::REPOS_DIRECTORY.to_s, mirror: true})
      expect { project.send :clone_repo }.to_not raise_error
    end
  end

  describe "#can_clone_repo" do
    it "adds an error if repository_url doesn't exist" do
      project = FactoryGirl.create(:project, repository_url: nil)
      expect(project.errors.count).to eql(0)
      project.send :can_clone_repo
      expect(project.errors.count).to eql(1)
    end
  end

  describe "#git?" do
    it "returns true if repository_url exists" do
      project = FactoryGirl.create(:project, repository_url: "https://example.com")
      expect(project.git?).to be_true
    end

    it "returns false if repository_url is empty" do
      project = FactoryGirl.create(:project, repository_url: "")
      expect(project.git?).to be_false
    end

    it "returns false if repository_url is nil" do
      project = FactoryGirl.create(:project, repository_url: nil)
      expect(project.git?).to be_false
    end
  end

  describe "#not_git?" do
    it "returns false if repository_url exists" do
      project = FactoryGirl.create(:project, repository_url: "https://example.com")
      expect(project.not_git?).to be_false
    end

    it "returns true if repository_url is nil" do
      project = FactoryGirl.create(:project, repository_url: nil)
      expect(project.not_git?).to be_true
    end
  end
end
