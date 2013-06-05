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

describe Importer::Base do
  include ImporterTesting

  describe "[importing strings]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de-DE' => true})

      @blob = FactoryGirl.create(:fake_blob, project: @project)
      yaml  = {'en-US' => {'foo' => 'bar'}}.to_yaml
      @blob.stub!(:blob).and_return(mock('Git::Object::Blob', contents: yaml))

      @commit   = FactoryGirl.create(:commit, project: @project)
      @importer = Importer::Yaml.new(@blob, 'some/path', @commit)
    end

    it "should only process a blob once" do
      @importer.should_receive(:import_strings).once.and_call_original
      @importer.import

      commit2   = FactoryGirl.create(:commit, project: @project)
      importer2 = Importer::Yaml.new(@blob, 'some/path', commit2)
      importer2.should_not_receive(:import_strings)
      importer2.import

      @commit.keys.pluck(:id).should eql(commit2.keys.pluck(:id))
    end
  end

  describe "[importing translations]" do
    before(:each) do
      @project  = FactoryGirl.create(:project,
                                     targeted_rfc5646_locales: {'en-US' => true, 'de-DE' => true})
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @commit   = FactoryGirl.create(:commit, project: @project)
      @importer = Importer::Yaml.new(@blob, 'some/path', @commit)
    end

    it "should not import translations under skipped paths"
    it "should not import translations under importer-specific skipped paths"

    it "should not reset the reviewed state for approved translations that are updated" do
      key = FactoryGirl.create(:key, project: @project, key: 'key')
      @commit.keys << key
      FactoryGirl.create :translation, key: key, rfc5646_locale: 'en-US'
      translation = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'de-DE', translated: true, approved: true)
      test_importer @importer, <<-YAML, nil, Locale.from_rfc5646('de-DE')
de-DE:
  key: new copy
      YAML
      translation.reload.should be_approved
      translation.copy.should eql('new copy')
    end

    it "should only import translations from included keys" do
      @project.update_attribute :key_inclusions, %w(in*)

      included_key = FactoryGirl.create(:key, key: 'included', project: @project)
      excluded_key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      @commit.keys << included_key << excluded_key
      FactoryGirl.create :translation, key: included_key, rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: excluded_key, rfc5646_locale: 'en-US'
      included = FactoryGirl.create(:translation, key: included_key, rfc5646_locale: 'de-DE', copy: 'old copy')
      excluded = FactoryGirl.create(:translation, key: excluded_key, rfc5646_locale: 'de-DE', copy: 'old copy')

      test_importer @importer, <<-YAML, nil, Locale.from_rfc5646('de-DE')
de-DE:
  included: new copy
  excluded: new copy
      YAML

      included.reload.copy.should eql('new copy')
      excluded.reload.copy.should eql('old copy')
    end

    it "should not import translations from excluded keys" do
      @project.update_attribute :key_exclusions, %w(*cl*)

      key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      @commit.keys << key
      FactoryGirl.create :translation, key: key, rfc5646_locale: 'en-US'
      translation = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'de-DE', copy: 'old copy')

      test_importer @importer, <<-YAML, nil, Locale.from_rfc5646('de-DE')
de-DE:
  excluded: new copy
      YAML

      translation.reload.copy.should eql('old copy')
    end

    it "should not import translations from locale-specific excluded keys" do
      @project.update_attribute :key_locale_exclusions, 'de-DE' => %w(*cl*)

      key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      @commit.keys << key
      FactoryGirl.create :translation, key: key, rfc5646_locale: 'en-US'
      translation = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'de-DE', copy: 'old copy')

      test_importer @importer, <<-YAML, nil, Locale.from_rfc5646('de-DE')
de-DE:
  excluded: new copy
      YAML

      translation.reload.copy.should eql('old copy')
    end

    it "should only import translations from locale-specific included keys" do
      @project.update_attribute :key_locale_inclusions, 'de-DE' => %w(in*)

      included_key = FactoryGirl.create(:key, key: 'included', project: @project)
      excluded_key = FactoryGirl.create(:key, key: 'excluded', project: @project)
      @commit.keys << included_key << excluded_key
      FactoryGirl.create :translation, key: included_key, rfc5646_locale: 'en-US'
      FactoryGirl.create :translation, key: excluded_key, rfc5646_locale: 'en-US'
      included = FactoryGirl.create(:translation, key: included_key, rfc5646_locale: 'de-DE', copy: 'old copy')
      excluded = FactoryGirl.create(:translation, key: excluded_key, rfc5646_locale: 'de-DE', copy: 'old copy')

      test_importer @importer, <<-YAML, nil, Locale.from_rfc5646('de-DE')
de-DE:
  included: new copy
  excluded: new copy
      YAML

      included.reload.copy.should eql('new copy')
      excluded.reload.copy.should eql('old copy')
    end
  end
end
