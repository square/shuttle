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
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit  = @project.commit!('8c6ba82822393219431dc74e2d4594cf8699a4f2')
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
        commit   = FactoryGirl.create(:commit, loading: true, user: FactoryGirl.create(:user))
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
  end

  context "[stats]" do
    context "[callbacks]" do
      before :all do
        Project.delete_all
        Timecop.freeze(Time.now)
        @created_at = Time.now
        @commit     = FactoryGirl.create(:commit, created_at: @created_at, loading: true, user: FactoryGirl.create(:user))
        Timecop.freeze(3.hours.from_now)
        @commit.loading = false
        @commit.save!
        Timecop.freeze(3.hours.from_now)
        @commit.recalculate_ready!
      end

      after(:all) { Timecop.return }

      it "should correctly compute the time to load" do
        expect(@commit.loaded_at.to_time).to eql(@created_at + 3.hours)
        expect(@commit.time_to_load).to eq(3.hours)
      end

      it "should correctly compute the time to translate" do
        expect(@commit.completed_at.to_time).to eql(@created_at + 6.hours)
        expect(@commit.time_to_translate).to eq(3.hours)
      end

      it "should correctly compute the time to complete" do
        expect(@commit.completed_at.to_time).to eql(@created_at + 6.hours)
        expect(@commit.time_to_complete).to eq(6.hours)
      end
    end

    context "[metrics]" do
      before :all do
        timespan = 30
        Timecop.freeze(Time.now.beginning_of_year)
        @last_date  = Date.today
        @first_date = Date.today - timespan.days

        Project.delete_all
        @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
        # Note that we include 1 day outside of boundary.  This is to verify that these metrics don't capture
        # dates outside of window.
        ((@first_date - 1.day)...@last_date).each do |date|
          FactoryGirl.create(
              :commit,
              project:      @project,
              created_at:   date,
              loaded_at:    date + 1.day,
              completed_at: date + 2.days,
          )

        end

        # Create an "anomalous" commit (a commit that belongs to a separate project)to also test for how they handle
        # for date filters
        FactoryGirl.create(
            :commit,
            created_at:   @first_date,
            loaded_at:    @first_date + (0.5).days,
            completed_at: @first_date + 1.day,
        )
      end
      after(:all) { Timecop.return }

      it "should correctly compute daily commits created metric for one project" do
        expect(Commit.daily_commits_created(@project.id)).to eql(
                                                                 (@first_date...@last_date).inject([]) do |daily_finishes, cur_date|
                                                                   daily_finishes << [cur_date.to_time.to_i, 1]
                                                                 end
                                                             )
      end

      it "should correctly compute daily commits finished metric for one project" do
        expect(Commit.daily_commits_finished(@project.id)).to eql(
                                                                  (@first_date...@last_date).inject([]) do |daily_finishes, cur_date|
                                                                    if cur_date == @first_date
                                                                      daily_finishes << [cur_date.to_time.to_i, 0]
                                                                    else
                                                                      daily_finishes << [cur_date.to_time.to_i, 1]
                                                                    end
                                                                  end
                                                              )
      end

      it "should correctly compute average load metric for one project" do
        expect(Commit.average_load_time(@project.id)).to eql(
                                                             (@first_date...@last_date).inject([]) do |mv_avg, cur_date|
                                                               mv_avg << [cur_date.to_time.to_i, 1.day.to_f]
                                                             end
                                                         )
      end

      it "should correctly compute average translation metric for one project" do
        expect(Commit.average_translation_time(@project.id)).to eql(
                                                                    (@first_date...@last_date).inject([]) do |mv_avg, cur_date|
                                                                      mv_avg << [cur_date.to_time.to_i, 1.day.to_f]
                                                                    end
                                                                )
      end

      it "should correctly compute average completion metric for one project" do
        expect(Commit.average_completion_time(@project.id)).to eql(
                                                                   (@first_date...@last_date).inject([]) do |mv_avg, cur_date|
                                                                     mv_avg << [cur_date.to_time.to_i, 2.day.to_f]
                                                                   end
                                                               )
      end

      it "should correctly compute daily commits created metric for all projects" do
        expect(Commit.daily_commits_created).to eql(
                                                    (@first_date...@last_date).inject([]) do |daily_finishes, cur_date|
                                                      if cur_date == @first_date
                                                        daily_finishes << [cur_date.to_time.to_i, 2]
                                                      else
                                                        daily_finishes << [cur_date.to_time.to_i, 1]
                                                      end
                                                    end
                                                )
      end

      it "should correctly compute daily commits finished metric for all projects" do
        expect(Commit.daily_commits_finished).to eql(
                                                     (@first_date...@last_date).inject([]) do |daily_finishes, cur_date|
                                                       case cur_date
                                                         when @first_date then
                                                           daily_finishes << [cur_date.to_time.to_i, 0]
                                                         when @first_date + 1 then
                                                           daily_finishes << [cur_date.to_time.to_i, 2]
                                                         else
                                                           daily_finishes << [cur_date.to_time.to_i, 1]
                                                       end
                                                     end
                                                 )
      end

      it "should correctly compute average load metric for all projects" do
        expect(Commit.average_load_time).to eql(
                                                (@first_date...@last_date).inject([]) do |mv_avg, cur_date|
                                                  case cur_date
                                                    when @first_date then
                                                      mv_avg << [cur_date.to_time.to_i, 6.day/7.0]
                                                    when @first_date + 1 then
                                                      mv_avg << [cur_date.to_time.to_i, 7.days/8.0]
                                                    else
                                                      mv_avg << [cur_date.to_time.to_i, 1.day.to_f]
                                                  end
                                                end
                                            )
      end
      it "should correctly compute average translation metric for all projects" do
        expect(Commit.average_translation_time).to eql(
                                                       (@first_date...@last_date).inject([]) do |mv_avg, cur_date|
                                                         case cur_date
                                                           when @first_date then
                                                             mv_avg << [cur_date.to_time.to_i, 1.day.to_f]
                                                           when @first_date + 1 then
                                                             mv_avg << [cur_date.to_time.to_i, 1.day.to_f]
                                                           else
                                                             mv_avg << [cur_date.to_time.to_i, 1.day.to_f]
                                                         end
                                                       end
                                                   )
      end
      it "should correctly compute average completion metric for all projects" do
        expect(Commit.average_completion_time).to eql(
                                                      (@first_date...@last_date).inject([]) do |mv_avg, cur_date|
                                                        case cur_date
                                                          when @first_date then
                                                            mv_avg << [cur_date.to_time.to_i, 13.days/7.0]
                                                          when @first_date + 1 then
                                                            mv_avg << [cur_date.to_time.to_i, 15.days/8.0]
                                                          else
                                                            mv_avg << [cur_date.to_time.to_i, 2.day.to_f]
                                                        end
                                                      end
                                                  )
      end

    end
  end

  describe "#recalculate_ready!" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit  = @project.commit!('HEAD')
    end

    before :each do
      @commit.keys.each(&:destroy)
      @commit.update_attribute(:completed_at, nil)
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
  end

  context "[hooks]" do

    context "webhooks" do
      before { @commit = FactoryGirl.create(:commit, ready: false) }
      context "if ready" do
        it "enqueues a webhook job if the state changed" do
          expect(@commit).not_to be_ready
          @commit.ready = true
          expect(WebhookPinger).to receive(:perform_once)
          @commit.save!
        end

        it "doesn't enqueue a webhook job if the state did not change" do
          @commit.ready = true
          @commit.save!
          @commit.ready = true
          expect(WebhookPinger).not_to receive(:perform_once)
          @commit.save!
        end

      end

      context "if not ready" do
        it "doesn't enqueue a webhook job even if state has changed" do
          @commit.ready = true
          @commit.save!
          @commit.ready = false
          expect(WebhookPinger).not_to receive(:perform_once)
          @commit.save!
        end

        it "doesn't enqueue a webhook job if state has not changed" do
          expect(WebhookPinger).not_to receive(:perform_once)
          @commit.save!
        end
      end
    end

    context "[mail hooks]" do
      it "sends an email to the translators and cc's the user when loading changes to false from true" do
        @commit = FactoryGirl.create(:commit, loading: true, user: FactoryGirl.create(:user))
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
        @commit = FactoryGirl.create(:commit, loading: true, user: FactoryGirl.create(:user), completed_at: 1.day.ago)
        ActionMailer::Base.deliveries.clear
        @commit.loading = false
        @commit.save!
        expect(ActionMailer::Base.deliveries.size).to be_zero
      end

      it "sends one email to the translators when loading changes to false if the commit has no user" do
        @commit = FactoryGirl.create(:commit, loading: true)
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
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      FactoryGirl.create :commit, project: project, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', skip_import: false
      expect(project.blobs.size).to eql(36) # should import all blobs
    end

    it "should cache a localization when ready" do
      project = FactoryGirl.create(:project, cache_localization: true, targeted_rfc5646_locales: {'en' => true, 'fr' => true})
      key1    = FactoryGirl.create(:key, project: project)
      key2    = FactoryGirl.create(:key, project: project)
      base1   = FactoryGirl.create(:translation, approved: true, key: key1)
      base2   = FactoryGirl.create(:translation, approved: true, key: key2)
      trans1  = FactoryGirl.create(:translation, approved: true, key: key1, rfc5646_locale: 'fr')
      trans2  = FactoryGirl.create(:translation, approved: nil, key: key2, rfc5646_locale: 'fr')
      commit  = FactoryGirl.create(:commit, project: project)
      key1.recalculate_ready!
      key2.recalculate_ready!

      commit.keys = [key1, key2]
      commit.recalculate_ready!
      expect(commit).not_to be_ready
      expect(Shuttle::Redis.exists(LocalizePrecompiler.new.key(commit))).to be_false

      trans2.update_attribute :approved, true
      expect(commit.reload).to be_ready
      expect(Shuttle::Redis.exists(LocalizePrecompiler.new.key(commit))).to be_true
    end

    it "should cache manifests when ready" do
      rb  = Mime::Type.lookup('application/x-ruby')
      yml = Mime::Type.lookup('text/x-yaml')

      project = FactoryGirl.create(:project, cache_manifest_formats: %w(rb yaml), targeted_rfc5646_locales: {'en' => true, 'fr' => true})
      key1    = FactoryGirl.create(:key, project: project)
      key2    = FactoryGirl.create(:key, project: project)
      base1   = FactoryGirl.create(:translation, approved: true, key: key1)
      base2   = FactoryGirl.create(:translation, approved: true, key: key2)
      trans1  = FactoryGirl.create(:translation, approved: true, key: key1, rfc5646_locale: 'fr')
      trans2  = FactoryGirl.create(:translation, approved: nil, key: key2, rfc5646_locale: 'fr')
      commit  = FactoryGirl.create(:commit, project: project)
      key1.recalculate_ready!
      key2.recalculate_ready!

      commit.keys = [key1, key2]
      commit.recalculate_ready!
      expect(commit).not_to be_ready
      expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, rb))).to be_false
      expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, yml))).to be_false

      trans2.update_attribute :approved, true
      expect(commit.reload).to be_ready
      expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, rb))).to be_true
      expect(Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, yml))).to be_true
    end
  end

  describe "[statistics methods]" do
    before :all do
      # create a commit with 2 total strings, 8 total translations, 4 required
      # translations, and 2 done required translations

      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'en' => true, 'fr' => true, 'de' => false, 'ja' => true})
      @commit = FactoryGirl.create(:commit, project: project)
      key1    = FactoryGirl.create(:key, project: project)
      key2    = FactoryGirl.create(:key, project: project)

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
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
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
  end

  describe "#all_translations_entered_for_locale?" do
    before :all do
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
    before :all do
      @commit      = FactoryGirl.create(:commit)
      @keys        = FactoryGirl.create_list(:key, 3)
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
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
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
end
