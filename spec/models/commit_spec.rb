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
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
    end

    before :each do
      @commit = FactoryGirl.create(:commit, project: @project, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
    end

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

    it "should import strings" do
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      project = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git")
      commit  = FactoryGirl.create(:commit, project: project, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', skip_import: false)
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
      File.exist?(LocalizePrecompiler.new.path(commit)).should be_false

      trans2.update_attribute :approved, true
      commit.reload.should be_ready
      File.exist?(LocalizePrecompiler.new.path(commit)).should be_true
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
      File.exist?(ManifestPrecompiler.new.path(commit, rb)).should be_false
      File.exist?(ManifestPrecompiler.new.path(commit, yml)).should be_false

      trans2.update_attribute :approved, true
      commit.reload.should be_ready
      File.exist?(ManifestPrecompiler.new.path(commit, rb)).should be_true
      File.exist?(ManifestPrecompiler.new.path(commit, yml)).should be_true
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
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: nil

      @commit.keys = [key1, key2]
    end

    it "should recalculate commit statistics correctly" do
      Commit.update_all({translations_total: 0, translations_done: 0, strings_total: 0}, id: @commit.id)

      @commit.translations_total!
      @commit.translations_done!
      @commit.strings_total!

      @commit.translations_total.should eql(4)
      @commit.translations_done.should eql(2)
      @commit.strings_total.should eql(2)
    end
  end
end
