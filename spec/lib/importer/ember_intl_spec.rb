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

require 'rails_helper'

RSpec.describe Importer::EmberIntl do
  context "[importing]" do
    context "[repo with valid files]" do
      before :each do
        @project = FactoryBot.create(:project,
                                      repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                      only_paths:     %w(ember-intl/),
                                      skip_imports:   Importer::Base.implementations.map(&:ident) - %w(ember_intl))
        @commit  = @project.commit!('HEAD')
      end

      it "should import strings from YAML files" do
        expect(@project.keys.for_key('root_key_yaml').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
        expect(@project.keys.for_key('nested_key_yaml.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
        expect(@project.keys.for_key('nested_key_yaml.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
      end

      it "should import strings from JSON files" do
        expect(@project.keys.for_key('root_key_json').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
        expect(@project.keys.for_key('nested_key_json.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
        expect(@project.keys.for_key('nested_key_json.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
      end
    end

    context "[repo with broken files]" do
      before :each do
        @project = FactoryBot.create(:project,
                                      repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s,
                                      only_paths:     %w(ember-intl-broken/),
                                      skip_imports:   Importer::Base.implementations.map(&:ident) - %w(ember_intl))
        @commit  = @project.commit!('b768471579ce072bb8949a40a45c77c2f30cdff4').reload
      end

      it "should add error to commit" do
        expect(@commit.import_errors.map{ |error| error.first }.sort).to eql(%w(JSON::ParserError Psych::SyntaxError).sort)
        expect(@commit.blobs.where(errored: true).count).to eql(2)
        expect(@commit.blobs.where(parsed: false).count).to eql(2)
        expect(@commit.blobs.where(parsed: true).count).to eql(0)
      end
    end
  end
end
