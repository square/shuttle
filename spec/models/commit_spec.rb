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
  context "[callbacks]" do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit = @project.commit!('8c6ba82822393219431dc74e2d4594cf8699a4f2')
    end

    context "[validations]" do
      it "should truncate commit messages" do
        expect(FactoryGirl.create(:commit, message: 'a'*300).message).to eql('a'*253 + '...')
      end
    end

    context "[before_save]" do
      before(:each) { Timecop.freeze(Time.now) }
      after(:each) { Timecop.return }

      it "should set loading at" do
        old_time = Time.now
        commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil, user: FactoryGirl.create(:user))
        Timecop.freeze(3.days.from_now)
        commit.loading = false
        commit.save!
        expect(commit.loaded_at.to_time).to eql(old_time + 3.days)
      end
    end

    context "[before_create]" do
      it "should save the commit's author" do
        expect(@commit.author).to eql('Rick Song')
        expect(@commit.author_email).to eql('ricksong@squareup.com')
      end
    end

    context "[after import]" do
      before(:each) do
        @commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil)
        ActionMailer::Base.deliveries.clear
        @commit.user = FactoryGirl.create(:user)
      end

      it "should not send an email if commit doesnt have import errors" do
        @commit.import_batch.jobs {}
        expect(ActionMailer::Base.deliveries.map(&:subject)).not_to include("[Shuttle] Error(s) occurred during the import")
      end

      it "should email if commit has import errors" do
        @commit.add_import_error_in_redis(StandardError.new("some fake error"), "in some/path/to/file")
        @commit.import_batch.jobs {}
        email = ActionMailer::Base.deliveries.select { |email| email.subject == "[Shuttle] Error(s) occurred during the import" }.first
        expect(email).to_not be_nil
        expect(email.to).to eql([@commit.user.email, @commit.author_email].compact.uniq)
        expect(email.body).to include("SHA: #{@commit.revision}", "StandardError - some fake error (in some/path/to/file)")
      end
    end
  end

  context "[callbacks]" do
    before :each do
      Timecop.freeze(Time.now)
      @created_at = Time.now
      @commit = FactoryGirl.create(:commit, created_at: @created_at, loading: true, loaded_at: nil, loaded_at: nil)
      Timecop.freeze(3.hours.from_now)
      @commit.loading = false
      @commit.save!
      Timecop.freeze(3.hours.from_now)
      @commit.recalculate_ready!
    end

    after(:each) { Timecop.return }

    it "should persist the loaded_at time" do
      expect(@commit.loaded_at.to_time).to eql(@created_at + 3.hours)
    end

    it "should persist the completed_at time" do
      expect(@commit.completed_at.to_time).to eql(@created_at + 6.hours)
    end
  end

  describe "#recalculate_ready!" do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit  = @project.commit!('HEAD', skip_import: true)
      @commit.keys.each(&:destroy)
      @commit.update_attribute(:completed_at, nil)
    end

    context "has never loaded" do
      it "should not do anything if it has never been loaded" do
        @commit.update_attribute(:loaded_at, nil)
        @commit.recalculate_ready!
        expect(@commit).not_to be_ready
      end

      it "should not do anything if it is currently loading" do
        @commit.update_attribute(:loaded_at, Time.now)
        @commit.update_attribute(:loading, true)
        @commit.recalculate_ready!
        expect(@commit).not_to be_ready
      end
    end

    context "has successfully loaded" do
      before :each do
        @commit.update_attribute(:loaded_at, Time.now)
        @commit.update_attribute(:loading, false)
      end

      it "should set ready to false for commits with unready keys" do
        @commit.keys << FactoryGirl.create(:key)
        @commit.keys << FactoryGirl.create(:key)
        FactoryGirl.create(:translation, copy: nil, key: @commit.keys.last)
        @commit.keys.last.recalculate_ready!

        @commit.recalculate_ready!
        expect(@commit).not_to be_ready
      end

      it "completed_at should remain nil if not ready" do
        @commit.keys << FactoryGirl.create(:key)
        @commit.keys << FactoryGirl.create(:key)
        FactoryGirl.create(:translation, copy: nil, key: @commit.keys.last)
        @commit.keys.last.recalculate_ready!

        @commit.recalculate_ready!
        expect(@commit).not_to be_ready
        expect(@commit.completed_at).to be_nil
      end

      it "should set ready to true for commits with all ready keys" do
        @commit.keys << FactoryGirl.create(:key)
        @commit.recalculate_ready!
        expect(@commit).to be_ready
      end

      it "should set ready to true for commits with no keys" do
        @commit.recalculate_ready!
        expect(@commit).to be_ready
      end

      it "should set completed_at to current time when ready" do
        Timecop.freeze(Time.now)
        start_time = Time.now

        @commit.keys << FactoryGirl.create(:key)
        Timecop.freeze(1.day.from_now)

        @commit.recalculate_ready!
        expect(@commit).to be_ready

        expect(@commit.completed_at).to eql(start_time + 1.day)
        Timecop.return
      end

      it "should not change completed_at if commit goes from ready to unready." do
        @commit.keys << FactoryGirl.create(:key)
        @commit.recalculate_ready!
        expect(@commit).to be_ready
        completed_time = @commit.completed_at

        FactoryGirl.create(:translation, copy: nil, key: @commit.keys.last)
        @commit.keys.last.recalculate_ready!
        @commit.recalculate_ready!

        expect(@commit).not_to be_ready
        expect(@commit.completed_at).to eql(completed_time)
      end

      it "should not set ready if there are import errors in redis" do
        @commit.recalculate_ready!
        expect(@commit).to be_ready

        @commit.add_import_error_in_redis(StandardError.new("Some Fake Error"), "in some/file.yml")
        @commit.recalculate_ready!

        expect(@commit).to_not be_ready
      end

      it "should not set ready if there are import errors in postgres" do
        @commit.recalculate_ready!
        expect(@commit).to be_ready

        @commit.update_attributes(import_errors: [['some/file.yml', "Some Fake Error"]])
        @commit.recalculate_ready!

        expect(@commit).to_not be_ready
      end
    end
  end

  context "[hooks]" do
    context "[mail hooks]" do
      it "sends an email to the translators and cc's the user when loading changes to false from true" do
        @commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil, user: FactoryGirl.create(:user))
        ActionMailer::Base.deliveries.clear
        @commit.loading = false
        @commit.save!
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first
        expect(email.to).to eql([Shuttle::Configuration.mailer.translators_list])
        expect(email.cc).to eql([@commit.user.email])
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

      it "sends one email to the translators when loading changes to false if the commit has no user" do
        @commit = FactoryGirl.create(:commit, loading: true, loaded_at: nil)
        ActionMailer::Base.deliveries.clear
        @commit.loading = false
        @commit.save!
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first
        expect(email.to).to eql([Shuttle::Configuration.mailer.translators_list])
        expect(email.subject).to eql('[Shuttle] New commit ready for translation')
        expect(email.body.to_s).to include("http://test.host/?project_id=#{@commit.project_id}&status=uncompleted")
      end

      it "sends an email when ready changes to true from false" do
        @commit = FactoryGirl.create(:commit, ready: false, user: FactoryGirl.create(:user))
        ActionMailer::Base.deliveries.clear
        @commit.ready = true

        @commit.project.key_inclusions += %w(inc_key_1 inc_key_2)
        @commit.project.key_exclusions += %w(exc_key_1 exc_key_2 exc_key_3)

        @commit.project.key_locale_inclusions = {"fr" => ["fr_exc_key_1", "fr_exc_key_2", "fr_exc_key_3"], "aa" => ["aa_exc_key_1", "aa_exc_key_2"]}
        @commit.project.key_locale_exclusions = {"ja" => ["ja_inc_key_1", "ja_inc_key_2", "ja_inc_key_3"]}

        @commit.project.only_paths += %w(only_path_1 only_path_2 only_path_1)
        @commit.project.skip_paths += %w(skip_path_1 skip_path_2)

        @commit.project.skip_importer_paths = {"Android XML" => ["an_skip_key_1", "an_skip_key_2", "an_skip_key_3"]}
        @commit.project.only_importer_paths = {"Ember.js" => ["em_only_key_1", "em_only_key_2", "em_only_key_3"], "ERb File" => ["erb_only_key_1", "erb_only_key_2"]}

        @commit.save!
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        email = ActionMailer::Base.deliveries.first
        expect(email.to).to eql([@commit.user.email])
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

    it "should import strings" do
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      FactoryGirl.create :commit, project: project, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', skip_import: false
      expect(project.blobs.size).to eql(36) # should import all blobs
    end

  end

  describe "[statistics methods]" do
    before :each do
      # create a commit with 2 total strings, 8 total translations, 4 required
      # translations, and 2 done required translations

      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'en' => true, 'fr' => true, 'de' => false, 'ja' => true})
      @commit = FactoryGirl.create(:commit, project: project)
      key1 = FactoryGirl.create(:key, project: project)
      key2 = FactoryGirl.create(:key, project: project)

      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: true
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: false
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: nil, copy: nil

      @commit.keys = [key1, key2]
    end

    it "should recalculate commit statistics correctly" do
      Commit.flush_memoizations @commit

      expect(@commit.translations_total).to eql(4)
      expect(@commit.translations_done).to eql(2)
      expect(@commit.translations_pending).to eql(1)
      expect(@commit.translations_new).to eql(1)
      expect(@commit.strings_total).to eql(2)
      expect(@commit.words_pending).to eql(19)
      expect(@commit.words_new).to eql(19)
    end
  end

  describe "#import_strings" do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
    end

    it "should call #import on all importer subclasses" do
      @project.commit! 'HEAD'
      expect(@project.keys.map(&:importer).uniq.sort).to eql(Importer::Base.implementations.map(&:ident).sort)
    end

    it "should not call #import on any disabled importer subclasses" do
      @project.update_attribute :skip_imports, %w(ruby yaml)
      @project.commit! 'HEAD'
      expect(@project.keys.map(&:importer).uniq.sort).to eql(Importer::Base.implementations.map(&:ident).sort - %w(ruby yaml))
      @project.update_attribute :skip_imports, []
    end

    it "should skip any importers for which #skip? returns true" do
      allow_any_instance_of(Importer::Yaml).to receive(:skip?).and_return(true)
      @project.commit! 'HEAD'
      expect(@project.keys.map(&:importer).uniq.sort).to eql(Importer::Base.implementations.map(&:ident).sort - %w(yaml))
    end

    it "clears the previous import errors" do
      commit = @project.commit!('HEAD', skip_import: true)
      commit.add_import_error_in_redis(StandardError.new("fake error"), "in fakefile")
      commit.update! import_errors: [["StandardError", "fake error (in fakefile)"]]
      expect(commit.import_errors_in_redis).to eql([["StandardError", "fake error (in fakefile)"]])
      expect(commit.import_errors).to eql([["StandardError", "fake error (in fakefile)"]])
      commit.import_strings
      commit.reload
      expect(commit.import_errors_in_redis).to eql([])
      expect(commit.import_errors).to eql([])
    end

    it "should set all blobs as parsed" do
      Blob.delete_all
      @project.commit!('HEAD')
      expect(Blob.where(parsed: false).count).to be_zero
    end

    it "should remove appropriate keys when reimporting after changed settings" do
      commit = @project.commit!('HEAD')
      expect(commit.keys.map(&:original_key)).to include('root')

      @project.update_attribute :key_exclusions, %w(roo*)
      commit.import_strings
      expect(commit.keys(true).map(&:original_key)).not_to include('root')
    end

    it "should only associate relevant keys with a new commit when cached blob importing is being used" do
      @project.update_attribute :key_exclusions, %w(skip_me)
      commit = @project.commit!('HEAD')
      blob = commit.blobs.first
      red_herring = FactoryGirl.create(:key, key: 'skip_me')
      FactoryGirl.create :blobs_key, key: red_herring, blob: blob

      commit.import_strings
      expect(commit.keys(true)).not_to include(red_herring)
    end

    it "should remove appropriate keys when reimporting after changed settings" do
      commit = @project.commit!('HEAD')
      expect(commit.keys.map(&:original_key)).to include('root')

      @project.update_attribute :key_exclusions, %w(roo*)
      commit.import_strings
      expect(commit.keys(true).map(&:original_key)).not_to include('root')
    end

    it "should only associate relevant keys with a new commit when cached blob importing is being use3d" do
      @project.update_attribute :key_exclusions, %w(skip_me)
      commit = @project.commit!('HEAD')
      blob = commit.blobs.first
      red_herring = FactoryGirl.create(:key, key: 'skip_me')
      FactoryGirl.create :blobs_key, key: red_herring, blob: blob

      commit.import_strings
      expect(commit.keys(true)).not_to include(red_herring)
    end
  end

  describe "#all_translations_entered_for_locale?" do
    before :each do
      @commit      = FactoryGirl.create(:commit)
      @keys        = FactoryGirl.create_list(:key, 4)
      @commit.keys += @keys
    end

    it "should return true if every translation is either pending approval, approved, or rejected" do
      FactoryGirl.create :translation, approved: nil, key: @keys[0], rfc5646_locale: 'de'
      FactoryGirl.create :translation, approved: true, key: @keys[1], rfc5646_locale: 'de'
      FactoryGirl.create :translation, approved: false, key: @keys[2], rfc5646_locale: 'de'

      # red herring
      FactoryGirl.create :translation, copy: nil, approved: nil, key: @keys[3], rfc5646_locale: 'fr'

      expect(@commit.all_translations_entered_for_locale?(Locale.from_rfc5646('de'))).to be_true
    end

    it "should return false otherwise" do
      FactoryGirl.create :translation, copy: nil, key: @keys[0], rfc5646_locale: 'de'
      FactoryGirl.create :translation, approved: true, key: @keys[1], rfc5646_locale: 'de'
      FactoryGirl.create :translation, approved: false, key: @keys[2], rfc5646_locale: 'de'

      expect(@commit.all_translations_entered_for_locale?(Locale.from_rfc5646('de'))).to be_false
    end
  end

  describe "#all_translations_approved_for_locale?" do
    before :each do
      @commit = FactoryGirl.create(:commit)
      @keys = FactoryGirl.create_list(:key, 3)
      @commit.keys += @keys
    end

    it "should return true if every translation is approved" do
      FactoryGirl.create :translation, approved: true, key: @keys[0], rfc5646_locale: 'de'
      FactoryGirl.create :translation, approved: true, key: @keys[1], rfc5646_locale: 'de'

      # red herring
      FactoryGirl.create :translation, approved: nil, key: @keys[2], rfc5646_locale: 'fr'

      expect(@commit.all_translations_approved_for_locale?(Locale.from_rfc5646('de'))).to be_true
    end

    it "should return false otherwise" do
      FactoryGirl.create :translation, approved: true, key: @keys[0], rfc5646_locale: 'de'
      t = FactoryGirl.create(:translation, approved: nil, key: @keys[1], rfc5646_locale: 'de')

      expect(@commit.all_translations_approved_for_locale?(Locale.from_rfc5646('de'))).to be_false

      t.update_attribute :approved, false
      expect(@commit.all_translations_approved_for_locale?(Locale.from_rfc5646('de'))).to be_false
    end
  end

  describe "#skip_key?" do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
    end

    it "should return true if the commit has a .shuttle.yml file given an excluded key" do
      @commit = @project.commit!('339d381517fef6cabde59a373c8757d35af87558')
      expect(@commit.skip_key?('commit_excluded_1')).to be_true
    end

    it "should return false if the commit has a .shuttle.yml file given a non-excluded key" do
      @commit = @project.commit!('339d381517fef6cabde59a373c8757d35af87558')
      expect(@commit.skip_key?('other_key')).to be_false
    end

    it "should return false if the commit does not have a .shuttle.yml file" do
      @commit = @project.commit!('8c6ba82822393219431dc74e2d4594cf8699a4f2')
      expect(@commit.skip_key?('commit_excluded_1')).to be_false
    end
  end

  describe "#commit" do
    it "raises Project::NotLinkedToAGitRepositoryError if repository_url is nil" do
      project = FactoryGirl.create(:project, repository_url: nil)
      commit = FactoryGirl.create(:commit, project: project)
      expect { commit.commit }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end

    it "returns the git commit object" do
      project = FactoryGirl.create(:project)
      repo = double('Git::Repo')
      commit = FactoryGirl.create(:commit, revision: 'abc123', project: project)

      commit_obj = double('Git::Object::Commit', revision: 'abc123')
      expect(File).to receive(:exist?).and_return(true)
      expect(Git).to receive(:bare).and_return(repo)
      expect(repo).to receive(:object).with("abc123").and_return(commit_obj)
      expect(commit.commit).to eql(commit_obj)
    end
  end

  describe "#commit!" do
    before :each do
      @project = FactoryGirl.create(:project)
      @commit = FactoryGirl.create(:commit, revision: 'abc123', project: @project)
      @repo = double('Git::Repo')
      @commit_obj = double('Git::Object::Commit', sha: 'abc123')
      allow(@project).to receive(:repo).and_yield(@repo)
      allow(@commit).to receive(:commit).and_return(@commit_obj)
    end

    it "returns the git object for the commit without fetching if it's already in local repo" do
      expect(@repo).to_not receive(:fetch)
      expect(@repo).to receive(:object).with('abc123').once.and_return(@commit_obj)
      expect(@commit.commit!).to eql(@commit_obj)
    end

    it "returns the git object for the commit after fetching if it's not initially in local repo, but is in the remote repo" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil, @commit_obj)
      expect(@commit.commit!).to eql(@commit_obj)
    end

    it "raises Git::CommitNotFoundError if the revision is not found" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil)
      expect { @commit.commit! }.to raise_error(Git::CommitNotFoundError, "Commit not found in git repo: abc123")
    end

    it "raises Project::NotLinkedToAGitRepositoryError if repository_url is nil" do
      project = FactoryGirl.create(:project, repository_url: nil)
      commit = FactoryGirl.create(:commit, project: project)
      expect { commit.commit }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end
  end

  describe "#git_url" do
    context "[on github]" do
      it "returns the correct url for a commit where project url is for https" do
        project = FactoryGirl.create(:project, repository_url: "https://github.com/mycompany/my-project.git")
        commit = FactoryGirl.create(:commit, revision: 'abc123', project: project)
        expect(commit.git_url).to eql("https://github.com/mycompany/my-project/commit/abc123")
      end

      it "returns the correct url for a commit where project url is for ssh" do
        project = FactoryGirl.create(:project, repository_url: "git@github.com:mycompany/my-project.git")
        commit = FactoryGirl.create(:commit, revision: 'abc123', project: project)
        expect(commit.git_url).to eql("https://github.com/mycompany/my-project/commit/abc123")
      end
    end

    context "[on github enterprise]" do
      it "returns the correct url for a commit where project url is for https" do
        project = FactoryGirl.create(:project, repository_url: "https://git.mycompany.com/all/my-project.git")
        commit = FactoryGirl.create(:commit, revision: 'abc123', project: project)
        expect(commit.git_url).to eql("https://git.mycompany.com/all/my-project/commit/abc123")
      end

      it "returns the correct url for a commit where project url is for ssh" do
        project = FactoryGirl.create(:project, repository_url: "git@git.mycompany.com:all/my-project.git")
        commit = FactoryGirl.create(:commit, revision: 'abc123', project: project)
        expect(commit.git_url).to eql("https://git.mycompany.com/all/my-project/commit/abc123")
      end
    end

    context "[on stash]" do
      it "returns the correct url for a commit" do
        project = FactoryGirl.create(:project, repository_url: "https://stash.mycompany.com/scm/all/my-project.git")
        commit = FactoryGirl.create(:commit, revision: 'abc123', project: project)
        expect(commit.git_url).to eql("https://stash.mycompany.com/projects/ALL/repos/my-project/commits/abc123")
      end
    end
  end
end
