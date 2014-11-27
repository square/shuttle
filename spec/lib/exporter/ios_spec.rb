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

require 'spec_helper'

describe Exporter::Ios do
  before :each do
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
        expect(entry).to be_regular
        contents = archive.read_data
        # contents.should start_with("\xFF\xFE") -- Some bug in Rspec prevents this from working. 
        expect(contents.bytes.to_a[0]).to eq(0xFF)
        expect(contents.bytes.to_a[1]).to eq(0xFE)
        entries[entry.pathname] = contents.force_encoding('UTF-16LE')
      end
    end

    expect(entries.size).to eql(2)

    body = entries['Resources/de-DE.lproj/Localizable-en-US.strings'].encode('UTF-8')
    expect(body).to include(<<-C)
/* This is a normal string. */
"I'm a string!" = "Ich bin ein String!";
    C
    expect(body).to include(<<-C)
/* This is also a normal string. */
"I'm also a string!" = "Ich bin auch ein String!";
    C

    body = entries['Resources/de-DE.lproj/More.strings'].encode('UTF-8')
    expect(body).to include(<<-C)
/* Saying hello. */
"Hello, world!" = "Hallo, Welt!";
    C
    expect(body).to include(<<-C)
/* Saying goodbye. */
"Goodbye, cruel world." = "Auf Wiedersehen, grausamer Welt.";
    C

    expect(entries).not_to include('/Resources/en-US.lproj/Some.xib')
  end

  describe ".valid?" do
    it "should return true for a valid tar-gz file" do
      smalltgz = "\x1F\x8B\b\b\xB1\x8E\xF8Q\x00\x03log.tar\x00\xED\x99\xCFO\xC20\x14\x80_'\xC6\x19/;\x19\x8F\xBDx\xF1\x80mi\xB7\xEBB\xF0hL\xDC\xC5\e\x121d\t?\x12\x1C\xF7\xFD\xE9\xB6\xF4I\x16\x10\x88\x89\e\"\xEFK\x9A\x0FX\xCB\xDE(\xAF\xEC\xD1\xF1lt\x0F5#\x84H\x8C\xE1\xD6J\xAB\xC4YH%\x96\xFE\x82K%\x93X\x8AD\x19\xCD\x85\x94\xC6$\xC0M\xDD\x819\x16\x1F\xC5`nC)\xF2\xC9\xCE~\x83\xE1$\x9F\xEE8\x8E\xD7\xB1\xF2\x910\xB6\xF3\xDF\xEE\xB7{Y?+f\xF3\xF7Z\xCEa?\x8FX\xEB\xED\xF3/\x95r\xF3o:\x89R\xB1\x8C\xED\xFCw\xB4Q\xC0E-\xD1\xACq\xE2\xF3\x0F\xE7\xD7\x17\x10\x00<\x0E\xDE\xF8S\xC6_8\xE2^\x83K\xDB\x94m\xDC6\xF7\xFC\xD9\rX\xF5\x88\x0E\x174\xF1[,\xF3\xBF\xD6\xEC\xDF\x97\xFFR\v\xA1\xD7\xF3_iI\xF9\xDF\x10\xAC\xBB\x18JX\xA6s\b\xDEp\xFB}\xD7\x10\xDB\x06A\xF5\xFD\x80\x96\x06\x82 \b\x828\x06\x98Wxu\xD80\b\x82\xF8\x83\xB8\xF5\x81\xA3St\xE9\xCD\xF0x\x80nU\xC6Dh\x8EN\xD1\xA57\xC3~\x01\xBA\x85\x0E\xD1\x11\x9A\xA3St\xE9\x8D\x8B\x16\xC3\xE2\x83\xE1\x99\x19V(\f\xAB\x10\xC6\xD1\xE9\x8F.\x99 N\x863\xAF\xC8\xFD\xFE?\xC0\xD6\xFA\x9F \x88\x7F\fk\xF5\xB2^\x17V\x05\xC1f\a\xDB^+\x8FK\xD8~\x13\x10\xF8?\vo*c9:E\x97\xDEt\#@\x10\x04\xD14\xCB\xFD\xBFQ^\xE4\xA3im\e\x80\xFB\xF6\xFF\x850\xEB\xFB\x7FF\xD3\xFE\x7F#\xDC\xB5\xED7\xE0\xD0A\x10\x04A\x10\x8D\xF3\t\n\xEE0\x8E\x00*\x00\x00"
      expect(Exporter::Ios.valid?(smalltgz)).to be_true
    end

    it "should return false for a syntactically invalid tar-gz file" do
      expect(Exporter::Ios.valid?('wat?')).to be_false
    end

    it "should return false for an empty strings file" do
      expect(Exporter::Ios.valid?('')).to be_false
    end
  end
end
