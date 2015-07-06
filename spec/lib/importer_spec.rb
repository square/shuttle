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

describe Importer::Base do
  describe "#base_rfc5646_locale" do
    it "returns blob's project's base rfc5646 locale" do
      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en-TR')
      blob = FactoryGirl.create(:fake_blob, project: project)
      commit = FactoryGirl.create(:commit, project: project)
      expect(Importer::Android.new(blob, commit).base_rfc5646_locale).to eql('en-TR')
    end
  end

  describe "[importing strings]" do
    before :each do
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
end
