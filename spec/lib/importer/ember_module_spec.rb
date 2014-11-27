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

describe Importer::EmberModule do
  context "[importing]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(ember-injection/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(ember_module))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from JS files" do
      expect(@project.keys.for_key('mod_root_key').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
      expect(@project.keys.for_key('mod_nested_key.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
      expect(@project.keys.for_key('mod_nested_key.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
    end

    it "should import strings from CoffeeScript files" do
      expect(@project.keys.for_key('mod_root_key_coffee').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
      expect(@project.keys.for_key('mod_nested_key_coffee.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
      expect(@project.keys.for_key('mod_nested_key_coffee.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
    end
  end

  context "[importing with dot notation]" do
    it "should properly import keys" do
      @project = FactoryGirl.create(:project,
                                    repository_url:      Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    base_rfc5646_locale: 'en',
                                    only_paths:          %w(ember-injection/),
                                    skip_imports:        Importer::Base.implementations.map(&:ident) - %w(ember_module))
      @commit  = @project.commit!('HEAD')

      expect(@project.keys.for_key('mod_dot_notation').first.translations.find_by_rfc5646_locale('en').copy).to eql('foo')
    end
  end
end
