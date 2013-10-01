# Copyright 2013 Square Inc.
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
  context "[validations]" do
    it "should truncate commit messages" do
      FactoryGirl.create(:commit, message: 'a'*300).message.should eql('a'*253 + '...')
    end
  end

  describe "#recalculate_ready!" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
    end

    before(:each) { @commit = @project.commit!('HEAD') }

    it "should set ready to false for commits with unready keys" do
      @commit.keys << FactoryGirl.create(:key, ready: false)
      @commit.keys << FactoryGirl.create(:key, ready: true)
      @commit.recalculate_ready!
      @commit.should_not be_ready
    end

    it "should set ready to true for commits with all ready keys" do
      @commit.keys << FactoryGirl.create(:key, ready: true)
      @commit.recalculate_ready!
      @commit.should be_ready
    end

    it "should set ready to true for commits with no keys" do
      @commit.recalculate_ready!
      @commit.should be_ready
    end
  end

  context "[hooks]" do

    context "webhooks" do
      before { @commit = FactoryGirl.create(:commit, ready: false) }
      context "if ready" do
        it "enqueues a webhook job if the state changed" do
          @commit.should_not be_ready
          @commit.ready = true
          WebhookPinger.should_receive(:perform_once)
          @commit.save!
        end

        it "doesn't enqueue a webhook job if the state did not change" do
          @commit.ready = true
          @commit.save!
          @commit.ready = true
          WebhookPinger.should_not_receive(:perform_once)
          @commit.save!
        end

      end

      context "if not ready" do
        it "doesn't enqueue a webhook job even if state has changed" do
          @commit.ready = true
          @commit.save!
          @commit.ready = false
          WebhookPinger.should_not_receive(:perform_once)
          @commit.save!
        end

        it "doesn't enqueue a webhook job if state has not changed" do
          WebhookPinger.should_not_receive(:perform_once)
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
        ActionMailer::Base.deliveries.size.should eql(1)
        email = ActionMailer::Base.deliveries.first
        email.to.should eql([Shuttle::Configuration.mailer.translators_list])
        email.cc.should eql([@commit.user.email])
        email.subject.should eql('[Shuttle] New commit ready for translation')
        email.body.to_s.should include("http://test.host/?project_id=#{@commit.project_id}&status=uncompleted")
      end

      it "sends one email to the translators when loading changes to false if the commit has no user" do
        @commit = FactoryGirl.create(:commit, loading: true)
        ActionMailer::Base.deliveries.clear
        @commit.loading = false
        @commit.save!
        ActionMailer::Base.deliveries.size.should eql(1)
        email = ActionMailer::Base.deliveries.first
        email.to.should eql([Shuttle::Configuration.mailer.translators_list])
        email.subject.should eql('[Shuttle] New commit ready for translation')
        email.body.to_s.should include("http://test.host/?project_id=#{@commit.project_id}&status=uncompleted")
      end

      it "sends an email when ready changes to true from false" do
        @commit = FactoryGirl.create(:commit, ready: false, user: FactoryGirl.create(:user))
        ActionMailer::Base.deliveries.clear
        @commit.ready = true
        @commit.save!
        ActionMailer::Base.deliveries.size.should eql(1)
        email = ActionMailer::Base.deliveries.first
        email.to.should eql([@commit.user.email])
        email.subject.should eql('[Shuttle] Finished translation of commit')
        email.body.to_s.should include(@commit.revision.to_s)
      end

      it "should not send an email when ready changes to true from false if the commit has no user or the user has no email" do
        @commit = FactoryGirl.create(:commit, ready: false)
        ActionMailer::Base.deliveries.clear
        @commit.ready = true
        @commit.save!
        ActionMailer::Base.deliveries.should be_empty
      end
    end

    it "should import strings" do
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      FactoryGirl.create :commit, project: project, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', skip_import: false
      project.blobs.size.should eql(36) # should import all blobs
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
      commit.should_not be_ready
      Shuttle::Redis.exists(LocalizePrecompiler.new.key(commit)).should be_false

      trans2.update_attribute :approved, true
      commit.reload.should be_ready
      Shuttle::Redis.exists(LocalizePrecompiler.new.key(commit)).should be_true
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
      commit.should_not be_ready
      Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, rb)).should be_false
      Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, yml)).should be_false

      trans2.update_attribute :approved, true
      commit.reload.should be_ready
      Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, rb)).should be_true
      Shuttle::Redis.exists(ManifestPrecompiler.new.key(commit, yml)).should be_true
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

      @commit.translations_total.should eql(4)
      @commit.translations_done.should eql(2)
      @commit.translations_pending.should eql(1)
      @commit.translations_new.should eql(1)
      @commit.strings_total.should eql(2)
      @commit.words_pending.should eql(19)
      @commit.words_new.should eql(19)
    end
  end

  describe "#import_strings" do
    before :each do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
    end

    it "should call #import on all importer subclasses" do
      @project.commit! 'HEAD'
      @project.keys.map(&:importer).uniq.sort.should eql(Importer::Base.implementations.map(&:ident).sort)
    end

    it "should not call #import on any disabled importer subclasses" do
      @project.update_attribute :skip_imports, %w(ruby yaml)
      @project.commit! 'HEAD'
      @project.keys.map(&:importer).uniq.sort.should eql(Importer::Base.implementations.map(&:ident).sort - %w(ruby yaml))
      @project.update_attribute :skip_imports, []
    end

    it "should skip any importers for which #skip? returns true" do
      Importer::Yaml.any_instance.stub(:skip?).and_return(true)
      @project.commit! 'HEAD'
      @project.keys.map(&:importer).uniq.sort.should eql(Importer::Base.implementations.map(&:ident).sort - %w(yaml))
    end
  end
end
