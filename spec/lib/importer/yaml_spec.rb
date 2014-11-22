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

# encoding: UTF-8
require 'spec_helper'

describe Importer::Yaml do
  context "[importing]" do
    context "[repo with valid files]" do
      before :each do
        @project = FactoryGirl.create(:project,
                                      repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                      only_paths:     %w(config/locales/),
                                      skip_imports:   Importer::Base.implementations.map(&:ident) - %w(yaml))
        @commit  = @project.commit!('HEAD')
      end

      it "should import strings from YAML files" do
        expect(@project.keys.for_key('root').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
        expect(@project.keys.for_key('nested.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
        expect(@project.keys.for_key('nested.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
      end

      it "should import string arrays" do
        expect(@project.keys.for_key('abbr_month_names[2]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Feb')
        expect(@project.keys.for_key('abbr_month_names[12]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Dec')
      end
    end

    context "[repo with broken files]" do
      before :each do
        @project = FactoryGirl.create(:project,
                                      repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s,
                                      only_paths:     %w(config/locales/),
                                      skip_imports:   Importer::Base.implementations.map(&:ident) - %w(yaml))
        @commit  = @project.commit!('e5f5704af3c1f84cf42c4db46dcfebe8ab842bde').reload
      end

      it "should add error to commit" do
        expect(@commit.import_errors).to eql([["Psych::SyntaxError", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1 (in /config/locales/ruby/broken.yml)"]])
        expect(@commit.blobs.where(errored: true).count).to eql(1)
        expect(@commit.blobs.where(parsed: false).count).to eql(1)
        expect(@commit.blobs.where(parsed: true).count).to eql(2)
      end
    end
  end
end
