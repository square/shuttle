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

describe Importer::Ember do
  context "[importing]" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(ember/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(ember))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from JS files" do
      expect(@project.keys.for_key('root_key').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
      expect(@project.keys.for_key('nested_key.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
      expect(@project.keys.for_key('nested_key.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
    end

    it "should import strings from CoffeeScript files" do
      expect(@project.keys.for_key('root_key_coffee').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('root')
      expect(@project.keys.for_key('nested_key_coffee.one').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('one')
      expect(@project.keys.for_key('nested_key_coffee.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('two')
    end

    it "should only import strings under the correct localization" do
      expect(@project.keys.for_key('appears_in_two_locales').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('English')
    end
  end

  context "[importing with dot notation]" do
    it "should properly import keys" do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url:      Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    base_rfc5646_locale: 'en',
                                    only_paths:          %w(ember/),
                                    skip_imports:        Importer::Base.implementations.map(&:ident) - %w(ember))
      @commit  = @project.commit!('HEAD')

      expect(@project.keys.for_key('dot_notation').first.translations.find_by_rfc5646_locale('en').copy).to eql('foo')
    end
  end

  context "[robust implementation" do
    it "should be more robust than just a JSON parser" do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url:      Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    base_rfc5646_locale: 'en-GB',
                                    only_paths:          %w(ember/),
                                    skip_imports:        Importer::Base.implementations.map(&:ident) - %w(ember))
      @commit  = @project.commit!('HEAD')

      expect(@project.keys.for_key('complex').first.translations.find_by_rfc5646_locale('en-GB').copy).to eql('bar100')
    end
  end
end
