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
require 'sidekiq/testing/inline'

describe Importer::Base do
  describe "[importing strings]" do
    before :each do

      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de-DE' => true})
      @commit  = @project.commit!('HEAD', skip_import: true)
    end

    it "should not import keys under skipped paths" do
      @project.update_attribute :skip_paths, %w(config/locales/ruby_also/)
      @commit.import_strings
      expect(@commit.keys.for_key('root')).not_to be_empty
      expect(@commit.keys.for_key('importer_path_skipped')).to be_empty
    end

    it "should not import keys under importer-specific skipped paths" do
      @project.update_attribute :skip_importer_paths, 'ruby' => %w(config/locales/ruby_also/)
      @commit.import_strings
      expect(@commit.keys.for_key('root')).not_to be_empty
      expect(@commit.keys.for_key('rootrb')).not_to be_empty
      expect(@commit.keys.for_key('importer_path_skipped')).not_to be_empty
      expect(@commit.keys.for_key('importer_path_skippedrb')).to be_empty
    end

    it "should not import keys not under whitelisted paths" do
      @project.update_attribute :only_paths, %w(config/locales/ruby/)
      @commit.import_strings
      expect(@commit.keys.for_key('root')).not_to be_empty
      expect(@commit.keys.for_key('importer_path_skipped')).to be_empty
    end

    it "should not import keys not under importer-specific whitelisted paths" do
      @project.update_attribute :only_importer_paths, 'ruby' => %w(config/locales/ruby/)
      @commit.import_strings
      expect(@commit.keys.for_key('root')).not_to be_empty
      expect(@commit.keys.for_key('rootrb')).not_to be_empty
      expect(@commit.keys.for_key('importer_path_skipped')).not_to be_empty
      expect(@commit.keys.for_key('importer_path_skippedrb')).to be_empty
    end
  end

  describe "[importing translations]" do
    before :each do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de-DE' => true})
      @commit  = @project.commit!('HEAD', skip_import: true)
    end

    it "should not import translations under skipped paths" do
      @project.update_attribute :skip_paths, %w(config/locales/ruby_also/)

      root_key    = FactoryGirl.create(:key, key: 'root', source_copy: 'root-de')
      skipped_key = FactoryGirl.create(:key, key: 'importer_path_skipped', source_copy: 'skipped-de')
      FactoryGirl.create :translation, key: root_key, copy: 'old', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: skipped_key, copy: 'old', rfc5646_locale: 'en-US'
      root_trans    = FactoryGirl.create(:translation, key: root_key, copy: 'old', rfc5646_locale: 'de-DE')
      skipped_trans = FactoryGirl.create(:translation, key: skipped_key, copy: 'old', rfc5646_locale: 'de-DE')
      @commit.keys << root_key << skipped_key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(root_trans.reload.copy).to eql('root-de')
      expect(skipped_trans.reload.copy).to eql('old')
    end

    it "should not import translations under importer-specific skipped paths" do
      @project.update_attribute :skip_importer_paths, 'ruby' => %w(config/locales/ruby_also/)

      skipped_key     = FactoryGirl.create(:key, key: 'importer_path_skippedrb', source_copy: 'skipped-de')
      not_skipped_key = FactoryGirl.create(:key, key: 'importer_path_skipped', source_copy: 'skipped-de')
      FactoryGirl.create :translation, key: skipped_key, copy: 'old', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: not_skipped_key, copy: 'old', rfc5646_locale: 'en-US'
      skipped_trans     = FactoryGirl.create(:translation, key: skipped_key, copy: 'old', rfc5646_locale: 'de-DE')
      not_skipped_trans = FactoryGirl.create(:translation, key: not_skipped_key, copy: 'old', rfc5646_locale: 'de-DE')
      @commit.keys << not_skipped_key << skipped_key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(not_skipped_trans.reload.copy).to eql('skipped-de')
      expect(skipped_trans.reload.copy).to eql('old')
    end

    it "should not import translations not under whitelisted paths" do
      @project.update_attribute :only_paths, %w(config/locales/ruby/)

      root_key    = FactoryGirl.create(:key, key: 'root', source_copy: 'root-de')
      skipped_key = FactoryGirl.create(:key, key: 'importer_path_skipped', source_copy: 'skipped-de')
      FactoryGirl.create :translation, key: root_key, copy: 'old', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: skipped_key, copy: 'old', rfc5646_locale: 'en-US'
      root_trans    = FactoryGirl.create(:translation, key: root_key, copy: 'old', rfc5646_locale: 'de-DE')
      skipped_trans = FactoryGirl.create(:translation, key: skipped_key, copy: 'old', rfc5646_locale: 'de-DE')
      @commit.keys << root_key << skipped_key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(root_trans.reload.copy).to eql('root-de')
      expect(skipped_trans.reload.copy).to eql('old')
    end

    it "should not import translations not under importer-specific whitelisted paths" do
      @project.update_attribute :only_importer_paths, 'ruby' => %w(config/locales/ruby/)

      skipped_key     = FactoryGirl.create(:key, key: 'importer_path_skippedrb', source_copy: 'skipped-de')
      not_skipped_key = FactoryGirl.create(:key, key: 'importer_path_skipped', source_copy: 'skipped-de')
      FactoryGirl.create :translation, key: skipped_key, copy: 'old', rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: not_skipped_key, copy: 'old', rfc5646_locale: 'en-US'
      skipped_trans     = FactoryGirl.create(:translation, key: skipped_key, copy: 'old', rfc5646_locale: 'de-DE')
      not_skipped_trans = FactoryGirl.create(:translation, key: not_skipped_key, copy: 'old', rfc5646_locale: 'de-DE')
      @commit.keys << not_skipped_key << skipped_key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(not_skipped_trans.reload.copy).to eql('skipped-de')
      expect(skipped_trans.reload.copy).to eql('old')
    end

    it "should only import translations from included keys" do
      @project.update_attribute :key_inclusions, %w(in*)

      included_key = FactoryGirl.create(:key, key: 'included', project: @project)
      excluded_key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      FactoryGirl.create :translation, key: included_key, rfc5646_locale: 'en-US', copy: 'old copy'
      FactoryGirl.create :translation, key: excluded_key, rfc5646_locale: 'en-US', copy: 'old copy'
      included = FactoryGirl.create(:translation, key: included_key, rfc5646_locale: 'de-DE', copy: 'old copy')
      excluded = FactoryGirl.create(:translation, key: excluded_key, rfc5646_locale: 'de-DE', copy: 'old copy')
      @commit.keys << included_key << excluded_key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(included.reload.copy).to eql('included-de')
      expect(excluded.reload.copy).to eql('old copy')
    end

    it "should not import translations from excluded keys" do
      @project.update_attribute :key_exclusions, %w(*cl*)

      key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      FactoryGirl.create :translation, key: key, rfc5646_locale: 'en-US', copy: 'old copy'
      translation = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'de-DE', copy: 'old copy')
      @commit.keys << key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(translation.reload.copy).to eql('old copy')
    end

    it "should not import translations from locale-specific excluded keys" do
      @project.update_attribute :key_locale_exclusions, 'de-DE' => %w(*cl*)

      key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      FactoryGirl.create :translation, key: key, rfc5646_locale: 'en-US', copy: 'old copy'
      translation = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'de-DE', copy: 'old copy')
      @commit.keys << key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(translation.reload.copy).to eql('old copy')
    end

    it "should only import translations from locale-specific included keys" do
      @project.update_attribute :key_locale_inclusions, 'de-DE' => %w(in*)

      included_key = FactoryGirl.create(:key, key: 'included', project: @project)
      excluded_key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      FactoryGirl.create :translation, key: included_key, rfc5646_locale: 'en-US', copy: 'old copy'
      FactoryGirl.create :translation, key: excluded_key, rfc5646_locale: 'en-US', copy: 'old copy'
      included = FactoryGirl.create(:translation, key: included_key, rfc5646_locale: 'de-DE', copy: 'old copy')
      excluded = FactoryGirl.create(:translation, key: excluded_key, rfc5646_locale: 'de-DE', copy: 'old copy')
      @commit.keys << included_key << excluded_key

      @commit.import_strings locale: Locale.from_rfc5646('de-DE')

      expect(included.reload.copy).to eql('included-de')
      expect(excluded.reload.copy).to eql('old copy')
    end
  end
end
