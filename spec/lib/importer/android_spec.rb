# encoding: utf-8

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

describe Importer::Android do
  describe "#import_file?" do
    it "should return false if it's not an XML file" do
      Importer::Android.new(FactoryGirl.create(:fake_blob), 'res/values/hello.txt').send(:import_file?).should be_false
    end

    it "should return false if it's in the wrong locale" do
      Importer::Android.new(FactoryGirl.create(:fake_blob), 'res/values-fr-rFR/strings.xml').send(:import_file?, Locale.from_rfc5646('fr-CA')).should be_false
      Importer::Android.new(FactoryGirl.create(:fake_blob), 'res/values/strings.xml').send(:import_file?, Locale.from_rfc5646('fr-CA')).should be_false
    end

    it "should return true if locale is nil and the file is in the base resources directory" do
      Importer::Android.new(FactoryGirl.create(:fake_blob), 'res/values/strings.xml').send(:import_file?).should be_true
    end

    it "should return false if it's not named strings.xml" do
      Importer::Android.new(FactoryGirl.create(:fake_blob), 'res/values/hello.xml').send(:import_file?).should be_false
    end

    it "should return true if locale matches the directory locale" do
      Importer::Android.new(FactoryGirl.create(:fake_blob), 'res/values-fr-rFR/strings.xml').send(:import_file?, Locale.from_rfc5646('fr-FR')).should be_true
    end
  end

  describe "#import_strings" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(java/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(android))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from XML files" do
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string[1]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Hello!')
    end

    it "should import string arrays" do
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string-array[1]/item[1]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Hello')
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string-array[1]/item[2]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('World')
    end

    it "should import plurals" do
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/plurals/item[1]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('world')
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/plurals/item[2]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('worlds')
    end

    it "should not import strings marked as untranslatable" do
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string[2]').should be_empty
    end

    it "should properly escape strings" do
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string[3]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Êtes-vous sûr ?')
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string[4]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql("Hello \\'world\\'")
      @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string[5]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql("Hello 'world'")
    end

    it "should add comments as context" do
      k = @project.keys.for_key('/java/basic-hdpi/strings.xml:/resources/string[6]').first
      k.context.should eql("This is not a date format string. Rather, it is hint text in a field, presented to the merchant.")
    end
  end
end
