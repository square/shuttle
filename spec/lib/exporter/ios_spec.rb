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

describe Exporter::Ios do
  before :all do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')

    # file 1
    key1     = FactoryGirl.create(:key,
                                  project: @project,
                                  key:     "I'm a string!",
                                  source:  '/Resources/en-US.lproj/Localizable-en-US.strings',
                                  context: "This is a normal string.")
    key2     = FactoryGirl.create(:key,
                                  project: @project,
                                  key:     "I'm also a string!",
                                  source:  '/Resources/en-US.lproj/Localizable-en-US.strings',
                                  context: "This is also a normal string.")
    FactoryGirl.create :translation,
                       key:           key1,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "I'm a string!",
                       copy:          "Ich bin ein String!"
    FactoryGirl.create :translation,
                       key:           key2,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "I'm also a string!",
                       copy:          "Ich bin auch ein String!"

    # file 2
    key3 = FactoryGirl.create(:key,
                              project: @project,
                              key:     "Hello, world!",
                              source:  '/Resources/en-US.lproj/More.strings',
                              context: "Saying hello.")
    key4 = FactoryGirl.create(:key,
                              project: @project,
                              key:     "Goodbye, cruel world.",
                              source:  '/Resources/en-US.lproj/More.strings',
                              context: "Saying goodbye.")
    FactoryGirl.create :translation,
                       key:           key3,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Hello, world!",
                       copy:          "Hallo, Welt!"
    FactoryGirl.create :translation,
                       key:           key4,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Goodbye, cruel world.",
                       copy:          "Auf Wiedersehen, grausamer Welt."

    # red herring; not a .strings file
    key5 = FactoryGirl.create(:key,
                              project: @project,
                              key:     "red herring",
                              source:  '/Resources/en-US.lproj/Some.xib')
    FactoryGirl.create :translation,
                       key:           key5,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "red herring",
                       copy:          "rote herring"

    @commit      = FactoryGirl.create(:commit, project: @project)
    @commit.keys = [key1, key2, key3, key4, key5]
  end

  it "should output translations in .tar format" do
    io = StringIO.new
    Exporter::Ios.new(@commit).export(io, @de)
    io.rewind

    entries = Hash.new
    Archive.read_open_memory(io.string, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
      while (entry = archive.next_header)
        entry.should be_regular
        contents = archive.read_data
        # contents.should start_with("\xFF\xFE") -- Some bug in Rspec prevents this from working. 
        contents.bytes.to_a[0].should == 0xFF
        contents.bytes.to_a[1].should == 0xFE
        entries[entry.pathname] = contents.force_encoding('UTF-16LE')
      end
    end

    entries.size.should eql(2)

    body = entries['Resources/de-DE.lproj/Localizable-en-US.strings'].encode('UTF-8')
    body.should include(<<-C)
/* This is a normal string. */
"I'm a string!" = "Ich bin ein String!";
    C
    body.should include(<<-C)
/* This is also a normal string. */
"I'm also a string!" = "Ich bin auch ein String!";
    C

    body = entries['Resources/de-DE.lproj/More.strings'].encode('UTF-8')
    body.should include(<<-C)
/* Saying hello. */
"Hello, world!" = "Hallo, Welt!";
    C
    body.should include(<<-C)
/* Saying goodbye. */
"Goodbye, cruel world." = "Auf Wiedersehen, grausamer Welt.";
    C

    entries.should_not include('/Resources/en-US.lproj/Some.xib')
  end
end
