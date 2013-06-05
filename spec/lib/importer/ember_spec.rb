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

describe Importer::Ember do
  include ImporterTesting

  let(:base_rfc5646_locale) { 'en-US' }

  before(:each) do
    @project  = FactoryGirl.create(:project, base_rfc5646_locale: base_rfc5646_locale)
    @blob     = FactoryGirl.create(:fake_blob, project: @project)
    @importer = Importer::Ember.new(@blob, 'some/path')
  end

  context "[importing]" do
    it "should import strings from JS files" do
      test_importer @importer, <<-JS
Ember.I18n.locales.translations["en-US"] = {
  CLDRDefaultLanguage: "en",
  root: "root",
  nested: {
    one: "one",
    2: "two"
  }
};
      JS

      @project.keys.count.should eql(3)
      @project.keys.for_key('root').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('root')
      @project.keys.for_key('nested.one').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('one')
      @project.keys.for_key('nested.2').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('two')
    end

    it "should import strings from CoffeeScript files" do
      test_importer @importer, <<-COFFEE, "foo/bar.coffee"
Ember.I18n.locales.translations["en-US"] =
  CLDRDefaultLanguage: "en"
  root: "root"
  nested:
    one: "one"
    2: "two"
      COFFEE

      @project.keys.count.should eql(3)
      @project.keys.for_key('root').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('root')
      @project.keys.for_key('nested.one').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('one')
      @project.keys.for_key('nested.2').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('two')
    end

    it "should only import strings under the correct localization" do
      test_importer @importer, <<-JS
Ember.I18n.locales.translations["en-US"] = { english: "English" };
Ember.I18n.locales.translations["de-DE"] = { english: "Englisch" };
var fr_FR = { english: 'Anglais' };
      JS

      @project.keys.count.should eql(1)
      @project.keys.for_key('english').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('English')
    end

    it "should be more robust than just a JSON parser" do
      test_importer @importer, <<-JS
var translations = new Object();
translations['foo'] = 'bar' + (10*10);
Ember.I18n.locales.translations["en-US"] = translations;
      JS

      @project.keys.count.should eql(1)
      @project.keys.for_key('foo').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('bar100')
    end

    context "when the translations are set using dot notation" do
      let(:base_rfc5646_locale) { 'en' }

      it "should still find the translations" do
        test_importer @importer, <<-JS
Ember.I18n.locales.translations.en = { foo: "bar" };
        JS

        @project.keys.count.should eql(1)
        @project.keys.for_key('foo').first.translations.find_by_rfc5646_locale('en').copy.should eql('bar')
      end
    end
  end
end
