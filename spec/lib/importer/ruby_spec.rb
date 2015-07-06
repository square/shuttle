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

describe Importer::Ruby do
  describe "#import_file?" do
    it "should only import from Ruby files under config/locales" do
      project = FactoryGirl.create(:project)
      commit = FactoryGirl.create(:commit, project: project)
      locales_blob = FactoryGirl.create(:fake_blob, project: project, path: '/config/locales/en-US.rb')
      languages_blob = FactoryGirl.create(:fake_blob, project: project, path: '/config/languages/en-US.rb')
      expect(Importer::Ruby.new(locales_blob, commit).send(:import_file?)).to be_true
      expect(Importer::Ruby.new(languages_blob, commit).send(:import_file?)).to be_false
    end
  end

  context "[importing]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(config/locales/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(ruby))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from .rb files" do
      expect(@project.keys.for_key('rootrb').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
      expect(@project.keys.for_key('nestedrb.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
      expect(@project.keys.for_key('nestedrb.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
    end

    it "should import string arrays" do
      expect(@project.keys.for_key('abbr_month_namesrb[2]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Feb')
      expect(@project.keys.for_key('abbr_month_namesrb[12]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Dec')
    end
  end
end
