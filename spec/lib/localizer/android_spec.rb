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

describe Localizer::Android do
  before :all do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')
    @commit  = FactoryGirl.create(:commit, project: @project)

    {
        '/java/basic-hdpi/strings.xml:/resources/string[1]'               => 'Hallo!',
        '/java/basic-hdpi/strings.xml:/resources/string[2]'               => 'Welt!',
        '/java/basic-hdpi/strings.xml:/resources/string[3]'               => '(de) Êtes-vous sûr ?',
        '/java/basic-hdpi/strings.xml:/resources/string[4]'               => "Hallo \\'Welt\\'",
        '/java/basic-hdpi/strings.xml:/resources/string[5]'               => "Hallo 'Welt'",
        '/java/basic-hdpi/strings.xml:/resources/string[6]'               => 'dd/MM/yyyy',
        '/java/basic-hdpi/strings.xml:/resources/string[7]'               => 'Hallo!',
        '/java/basic-hdpi/strings.xml:/resources/string[8]'               => '‘guillemets’',
        '/java/basic-hdpi/strings.xml:/resources/string-array[1]/item[1]' => 'Hallo',
        '/java/basic-hdpi/strings.xml:/resources/string-array[1]/item[2]' => 'Welt',
        '/java/basic-hdpi/strings.xml:/resources/string-array[2]/item[1]' => 'Hallo',
        '/java/basic-hdpi/strings.xml:/resources/string-array[2]/item[2]' => 'Welt',
        '/java/basic-hdpi/strings.xml:/resources/plurals/item[1]'         => 'Welt',
        '/java/basic-hdpi/strings.xml:/resources/plurals/item[2]'         => 'Welten'
    }.each do |key, value|
      key_obj = FactoryGirl.create(:key, key: key, project: @project, source: '/java/basic-hdpi/strings.xml')
      FactoryGirl.create :translation, key: key_obj, copy: value, source_locale: @en, locale: @de
      @commit.keys << key_obj
    end
  end

  it "should localize an Android XML file" do
    input_file = Localizer::File.new("java/basic-hdpi/strings.xml", <<-XML)
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string name="string">Hello!</string>
  <string-array name="array">
	<item>Hello</item>
	<item>World</item>
  </string-array>
  <plurals name="plural">
	<item quantity="one">world</item>
	<item quantity="other">worlds</item>
  </plurals>
  <string name="excluded" translatable="false">World!</string>
  <string name="special_chars">Êtes-vous sûr\u00a0?</string>
  <string name="quoted_escaped">"Hello \\'world\\'"</string>
  <string name="unquoted_escaped">Hello \\'world\\'</string>
  <!--
	- This is not a date format string. Rather, it is hint text in a field,
	- presented to the merchant.
	-->
  <string name="with_context">MM/dd/yyyy</string>
  <string name="attributed_string" formatted="false">Hello!</string>
  <string name="smart_quotes">‘smart’ quotes</string>
  <string-array name="attributed_array">
	<item>Hello</item>
	<item formatted="false">World</item>
  </string-array>
</resources>
    XML
    output_file = Localizer::File.new

    Localizer::Android.new(@project, @commit.translations).localize input_file, output_file, @de

    output_file.path.should eql('java/basic-de-rDE-hdpi/strings.xml')
    output_file.content.should eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string name="string">Hallo!</string>
  <string-array name="array">
	<item>Hallo</item>
	<item>Welt</item>
  </string-array>
  <plurals name="plural">
	<item quantity="one">Welt</item>
	<item quantity="other">Welten</item>
  </plurals>
  <string name="excluded" translatable="false">Welt!</string>
  <string name="special_chars">(de) Êtes-vous sûr ?</string>
  <string name="quoted_escaped">Hallo \\\\\\'Welt\\\\\\'</string>
  <string name="unquoted_escaped">Hallo \\'Welt\\'</string>
  <!--
	- This is not a date format string. Rather, it is hint text in a field,
	- presented to the merchant.
	-->
  <string name="with_context">dd/MM/yyyy</string>
  <string name="attributed_string" formatted="false">Hallo!</string>
  <string name="smart_quotes">‘guillemets\\'</string>
  <string-array name="attributed_array">
	<item>Hallo</item>
	<item formatted="false">Welt</item>
  </string-array>
</resources>
    XML
  end
end
