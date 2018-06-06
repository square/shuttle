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

RSpec.describe Exporter::Strings do
  before :each do
    @project = FactoryBot.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')

    key1 = FactoryBot.create(:key,
                              project:      @project,
                              key:          "Resources/en.lproj/stuff.strings:dialogue.marta.1",
                              original_key: "dialogue.marta.1",
                              context:      "Marta is trying to be sincere and sweet.")
    FactoryBot.create :translation,
                       key:           key1,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Te Quiero.",
                       copy:          "Te Quiero."

    key2 = FactoryBot.create(:key,
                              project:      @project,
                              key:          "Resources/en.lproj/stuff.strings:dialogue.gob.1",
                              original_key: "dialogue.gob.1",
                              context:      "GOB is being insensitive to her culture.")
    FactoryBot.create :translation,
                       key:           key2,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "English, please.",
                       copy:          "Deutsch, bitte."

    key3 = FactoryBot.create(:key,
                              project:      @project,
                              key:          "Resources/en.lproj/stuff.strings:dialogue.marta.2",
                              original_key: "dialogue.marta.2",
                              context:      "Marta capitulates and repeats in English.")
    FactoryBot.create :translation,
                       key:           key3,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "I love you.",
                       copy:          "Ich liebe dich."

    key4 = FactoryBot.create(:key,
                              project:      @project,
                              key:          "Resources/en.lproj/stuff.strings:dialogue.gob.2",
                              original_key: "dialogue.gob.2")
    FactoryBot.create :translation,
                       key:           key4,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Great. Now I'm late for work.",
                       copy:         "Toll. Jetzt bin ich spät zur Arbeit."

                       @commit      = FactoryBot.create(:commit, project: @project)
    @commit.keys = [key1, key2, key3, key4]
  end

  it "should output translations in Cocoa format" do
    io = StringIO.new
    Exporter::Strings.new(@commit).export(io, @de)

    output = io.string.force_encoding('UTF-16').encode('UTF-8')
    expect(output).to include(<<-C)
"dialogue.gob.2" = "Toll. Jetzt bin ich spät zur Arbeit.";
    C
    expect(output).to include(<<-C)
/* Marta capitulates and repeats in English. */
"dialogue.marta.2" = "Ich liebe dich.";
    C
    expect(output).to include(<<-C)
/* GOB is being insensitive to her culture. */
"dialogue.gob.1" = "Deutsch, bitte.";
    C
    expect(output).to include(<<-C)
/* Marta is trying to be sincere and sweet. */
"dialogue.marta.1" = "Te Quiero.";
    C
  end

  it "should properly escape strings" do
    key = FactoryBot.create(:key,
                             project:      @project,
                             key:          "Resources/en.lproj/stuff.strings:Lots of special characters.",
                             original_key: "Lots of special characters.")
    FactoryBot.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Lots of special characters.",
                       copy:          "There\'re lots\n of \"special\" \t characters.\r"
    @commit.keys = [key]

    io = StringIO.new
    Exporter::Strings.new(@commit).export(io, @de)

    output = io.string.force_encoding('UTF-16').encode('UTF-8')
    expect(output).to include(<<-C)
"Lots of special characters." = "There\\'re lots\\n of \\"special\\" \\t characters.\\r";
    C
  end

  describe ".valid?" do
    it "should return true for a syntactically valid strings file" do
      expect(Exporter::Strings.valid?(<<-EOS)).to be_truthy
"foo" = "bar";
"foo[1]" = "bar two.";
      EOS
      expect(Exporter::Strings.valid?('"a"="b";')).to be_truthy
      expect(Exporter::Strings.valid?('"a\\""="b\\"";')).to be_truthy
    end

    it "should return false for a syntactically invalid strings file" do
      expect(Exporter::Strings.valid?('"foo"=;')).to be_falsey
      expect(Exporter::Strings.valid?('"foo"=""foo";')).to be_falsey
      expect(Exporter::Strings.valid?('="foo";')).to be_falsey
      expect(Exporter::Strings.valid?('"foo"="foo"')).to be_falsey
      expect(Exporter::Strings.valid?('hi!')).to be_falsey
      expect(Exporter::Strings.valid?("\"foo\"=\n=\"foo\"")).to be_falsey
    end

    it "should return false for an empty strings file" do
      expect(Exporter::Strings.valid?('')).to be_falsey
    end
  end
end
