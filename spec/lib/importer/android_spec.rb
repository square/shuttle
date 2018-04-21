# encoding: utf-8

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

RSpec.describe Importer::Android do
  describe "#import_file?" do
    before :each do
      @project = FactoryBot.create(:project, base_rfc5646_locale: 'en')
      @commit = FactoryBot.create(:commit, project: @project)
      @blob = FactoryBot.create(:fake_blob, project: @project)
    end

    it "should return false if it's not an XML file" do
      @blob.update! path: 'res/values/hello.txt'
      expect(Importer::Android.new(@blob, @commit).send(:import_file?)).to be_falsey
    end

    it "should return false if it's in the wrong locale" do
      @project.update_column :base_rfc5646_locale, 'fr-CA'
      @blob.update! path: 'res/values-fr-rFR/strings.xml'
      expect(Importer::Android.new(@blob, @commit).send(:import_file?)).to be_falsey
    end

    it "should return true if the file is in the base resources directory" do
      @blob.update! path: 'res/values/strings.xml'
      expect(Importer::Android.new(@blob, @commit).send(:import_file?)).to be_truthy
    end

    it "should return false if it's not named strings.xml" do
      @blob.update! path: 'res/values/hello.xml'
      expect(Importer::Android.new(@blob, @commit).send(:import_file?)).to be_falsey
    end

    it "should return true if locale matches the directory locale" do
      @project.update_column :base_rfc5646_locale, 'fr-FR'
      @blob.update! path: 'res/values-fr-rFR/strings.xml'
      expect(Importer::Android.new(@blob, @commit).send(:import_file?)).to be_truthy
    end
  end

  describe "#import_strings" do
    before :each do
      @project = FactoryBot.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(java/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(android))
      @commit  = @project.commit!('4fe357edecbb3cc556b53e713e56975c4bbc11a7')
    end

    it "should import strings from XML files" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:string').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Hello!')
    end

    it "should import string arrays" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:array[0]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Hello')
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:array[1]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('World')
    end

    it "should import plurals" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:plural[one]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('world')
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:plural[other]').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('worlds')
    end

    it "should not import strings marked as untranslatable" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:excluded')).to be_empty
    end

    it "should properly escape strings" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:unicode_chars').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Êtes-vous sûr ?')
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:escaped_chars').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("Hello\\\n@\\nworld!")
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:newlines').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("Hello\n\n   world!")
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:quoted').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('"Hello"')
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:quoted_escaped').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("\"Hello \\'world\\'\"")
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:unquoted_escaped').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("Hello 'world'")
    end

    it "should properly strip non-explicit new lines" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:implied_new_lines').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("Hello Hello World!!\n\nHello World.")
    end

    it "should add comments as context" do
      k = @project.keys.for_key('/java/basic-hdpi/strings.xml:with_context').first
      expect(k.context).to eql("This is not a date format string. Rather, it is hint text in a field, presented to the merchant.")
    end

    it "should strip leading and trailing spaces or newlines" do
      expect(@project.keys.for_key('/java/basic-hdpi/strings.xml:leading_newline').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Hello')
    end
  end

  describe "#unescape" do
    before :each do
      @project = FactoryBot.create(:project, base_rfc5646_locale: 'en')
      @commit = FactoryBot.create(:commit, project: @project)
      @blob = FactoryBot.create(:fake_blob, project: @project)
    end

    it "should unescape strings properly" do
      expect(Importer::Android.new(@blob, @commit).send(:unescape, '\\u003A 1 min left on break')).to eql(': 1 min left on break');
      expect(Importer::Android.new(@blob, @commit).send(:unescape, '\\u003a 1 min left on break')).to eql(': 1 min left on break');
    end
  end
end
