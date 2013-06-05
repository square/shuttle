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

# encoding: utf-8

require 'spec_helper'

describe Importer::Android do
  include ImporterTesting

  describe "#import_file?" do
    before(:all) { @importer = Importer::Android.new(FactoryGirl.create(:fake_blob), 'ignored') }

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
    before(:each) do
      @project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Android.new(@blob, 'some/path')
    end

    it "should import strings from XML files" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="hello">Hello!</string>
</resources>
      XML

      @project.keys.count.should eql(1)
      @project.keys.for_key('string:values-hdpi:hello').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Hello!')
    end

    it "should import string arrays" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string-array name="hello">
      <item>Hello</item>
      <item>World</item>
    </string-array>
</resources>
      XML

      @project.keys.count.should eql(2)
      @project.keys.for_key('array:values-hdpi:hello:0').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Hello')
      @project.keys.for_key('array:values-hdpi:hello:1').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('World')
    end

    it "should import plurals" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <plurals name="hello">
      <item quantity="one">world</item>
      <item quantity="other">worlds</item>
    </plurals>
</resources>
      XML

      @project.keys.count.should eql(2)
      @project.keys.for_key('plural:values-hdpi:hello:one').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('world')
      @project.keys.for_key('plural:values-hdpi:hello:other').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('worlds')
    end

    it "should not import strings marked as untranslatable" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="hello">Hello!</string>
    <string name="world" translatable="false">World!</string>
</resources>
      XML

      @project.keys.count.should eql(1)
      @project.keys.for_key('string:values-hdpi:hello').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Hello!')
    end

    it "should properly escape strings" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string name="receipt_are_you_sure">Êtes-vous sûr\u00a0?</string>
</resources>
      XML

      @project.keys.count.should eql(1)
      @project.keys.for_key('string:values-hdpi:receipt_are_you_sure').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Êtes-vous sûr ?')
    end

    it "should add comments as context" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <!--
    - This is not a date format string. Rather, it is hint text in a field,
    - presented to the merchant.
    -->
  <string name="date_hint">MM/dd/yyyy</string>
</resources>
      XML

      @project.keys.count.should eql(1)
      k = @project.keys.for_key('string:values-hdpi:date_hint').first
      k.context.should eql("This is not a date format string. Rather, it is hint text in a field, presented to the merchant.")
    end

    it "should preserve tag attributes" do
      test_importer @importer, <<-XML, 'res/values-hdpi/strings.xml'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="hello" formatted="false">Hello!</string>
    <string-array name="hello">
      <item>Hello</item>
      <item formatted="false">World</item>
    </string-array>
</resources>
      XML

      @project.keys.count.should eql(3)
      @project.keys.for_key('string:values-hdpi:hello').first.other_data['attributes'].should eql([%w(formatted false)])
      @project.keys.for_key('array:values-hdpi:hello:0').first.other_data['attributes'].should be_blank
      @project.keys.for_key('array:values-hdpi:hello:1').first.other_data['attributes'].should eql([%w(formatted false)])
    end
  end
end
