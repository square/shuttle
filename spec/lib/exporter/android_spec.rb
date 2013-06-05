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

describe Exporter::Android do
  before :all do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')
    @commit  = FactoryGirl.create(:commit, project: @project)

    # normal string
    key      = FactoryGirl.create(:key,
                                  project:      @project,
                                  key:          'string:values-hdpi:normal-string',
                                  original_key: 'normal-string',
                                  source:       '/res/values-hdpi/strings.xml',
                                  context:      "This is a normal string.",
                                  other_data:   {'attributes' => [%w(formatted false)]})
    @commit.keys << key
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "I’ve got \\n a string!",
                       copy:          "Ich hab’ \\n ein String!"

    # string array
    key = FactoryGirl.create(:key,
                             project:      @project,
                             key:          'array:values-hdpi:numbers:1',
                             original_key: 'numbers',
                             source:       '/res/values-hdpi/strings.xml')
    @commit.keys << key
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "one",
                       copy:          "eins"
    key = FactoryGirl.create(:key,
                             project:      @project,
                             key:          'array:values-hdpi:numbers:0',
                             original_key: 'numbers',
                             source:       '/res/values-hdpi/strings.xml')
    @commit.keys << key
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "zero",
                       copy:          "null"

    # plural set
    key = FactoryGirl.create(:key,
                             project:      @project,
                             key:          'plurals:values-hdpi:cat:one',
                             original_key: 'cat',
                             source:       '/res/values-hdpi/strings.xml')
    @commit.keys << key
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "cat",
                       copy:          "Katze"
    key = FactoryGirl.create(:key,
                             project:      @project,
                             key:          'plurals:values-hdpi:cat:other',
                             original_key: 'cat',
                             source:       '/res/values-hdpi/strings.xml')
    @commit.keys << key
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "cats",
                       copy:          "Kätzen"

    # red herring: not an xml file
    key = FactoryGirl.create(:key,
                             project:      @project,
                             key:          'string:values-hdpi:red-herring',
                             original_key: 'red-herring',
                             source:       '/res/values-hdpi/strings.foo')
    @commit.keys << key
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "red herring",
                       copy:          "rote herring"
  end

  it "should output translations in .tar format" do
    io = StringIO.new
    Exporter::Android.new(@commit).export(io, @de)
    io.rewind

    entries = Hash.new
    Archive.read_open_memory(io.string, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
      while (entry = archive.next_header)
        entry.should be_regular
        entries[entry.pathname] = archive.read_data.force_encoding('UTF-8')
      end
    end

    entries.size.should eql(1)
    entries.keys.first.should eql('res/values-de-rDE-hdpi/strings.xml')
    entries.values.first.should eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string formatted="false" name="normal-string">Ich hab\\' \\n ein String!</string>
  <string-array name="numbers">
    <item>null</item>
    <item>eins</item>
  </string-array>
  <plurals name="cat">
    <item quantity="one">Katze</item>
    <item quantity="other">Kätzen</item>
  </plurals>
</resources>
    XML

    entries.should_not include('/res/values-de-rDE-hdpi/strings.foo')
  end
end
