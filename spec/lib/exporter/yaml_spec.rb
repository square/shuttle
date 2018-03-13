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

RSpec.describe Exporter::Yaml do
  before :each do
    @source_locale = Locale.from_rfc5646('en-US')
    @target_locale = Locale.from_rfc5646('de-DE')
    @project       = FactoryBot.create(:project)
    @commit        = FactoryBot.create(:commit, project: @project)

    marta1      = FactoryBot.create(:key,
                                     project: @project,
                                     key:     "dialogue.marta[1]")
    marta2      = FactoryBot.create(:key,
                                     project: @project,
                                     key:     "dialogue.marta[2]")
    gob1        = FactoryBot.create(:key,
                                     project: @project,
                                     key:     "dialogue.gob[1]")
    gob2        = FactoryBot.create(:key,
                                     project: @project,
                                     key:     "dialogue.gob[2]")
    @commit.keys = [marta1, gob1, marta2, gob2]

    FactoryBot.create :translation,
                       key:           marta1,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "Te Quiero.",
                       copy:          "Te Quiero."
    FactoryBot.create :translation,
                       key:           gob1,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "English, please.",
                       copy:          "Deutsch, bitte."
    FactoryBot.create :translation,
                       key:           marta2,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "I love you.",
                       copy:          "Ich liebe dich."
    FactoryBot.create :translation,
                       key:           gob2,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "Great. Now I'm late for work.",
                       copy:          "Toll. Jetzt bin ich spät zur Arbeit."
  end

  it "should output translations in YAML format" do
    io = StringIO.new
    Exporter::Yaml.new(@commit).export(io, @target_locale)
    # normalize trailing spaces
    str = io.string.split("\n").map(&:rstrip).join("\n")
    expect(str).to eql(<<-YAML.chomp)
---
de-DE:
  dialogue:
    gob:
    -
    - Deutsch, bitte.
    - Toll. Jetzt bin ich spät zur Arbeit.
    marta:
    -
    - Te Quiero.
    - Ich liebe dich.
    YAML
  end

  context "[deduping]" do
    it "should not de-dupe ja translations from en" do
      ja = Locale.from_rfc5646('ja')

      same         = FactoryBot.create(:key, project: @project, key: 'same')
      different    = FactoryBot.create(:key, project: @project, key: 'different')
      @commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "異なる"

      io = StringIO.new
      Exporter::Yaml.new(@commit).export(io, ja)
      expect(io.string).to eql(<<-YAML)
---
ja:
  different: 異なる
  same: Same
      YAML
    end

    it "should de-dupe ja-JP translations from ja if ja is a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      @project.update_attribute :locale_requirements, @source_locale => true, ja => true, ja_JP => true

      same         = FactoryBot.create(:key, project: @project, key: 'same')
      different    = FactoryBot.create(:key, project: @project, key: 'different')
      @commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryBot.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::Yaml.new(@commit).export(io, ja_JP)
      expect(io.string).to eql(<<-YAML)
---
ja-JP:
  different: Different (ja-JP)
      YAML
    end

    it "should not de-dupe ja-JP translations from ja if ja is not a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      @project.update_attribute :locale_requirements, @source_locale => true, ja => false, ja_JP => true

      same         = FactoryBot.create(:key, project: @project, key: 'same')
      different    = FactoryBot.create(:key, project: @project, key: 'different')
      @commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryBot.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::Yaml.new(@commit).export(io, ja_JP)
      expect(io.string).to eql(<<-YAML)
---
ja-JP:
  different: Different (ja-JP)
  same: Same (ja)
      YAML
    end

    it "should not include a required locale in the manifest if it is an exact replica of a parent locale" do
      project = FactoryBot.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'fr-CA'=> true })
      key = FactoryBot.create(:key, project: project, key: "test")
      commit = FactoryBot.create(:commit, project: project)
      commit.keys = [key]
      FactoryBot.create :translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr',    source_copy: key.source_copy, copy: "Translated", approved: true
      FactoryBot.create :translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr-CA', source_copy: key.source_copy, copy: "Translated", approved: true

      fr = Locale.from_rfc5646('fr')
      frCA = Locale.from_rfc5646('fr-CA')
      io = StringIO.new
      Exporter::Yaml.new(commit).export(io, fr, frCA)
      expect(io.string).to eql(<<-YAML)
---
fr:
  test: Translated
      YAML
    end

  end

  it "should not include untranslated translations when partial=true" do
    project     = FactoryBot.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
    key1         = FactoryBot.create(:key, project: project, key: 'test1')
    key2         = FactoryBot.create(:key, project: project, key: 'test2')
    commit      = FactoryBot.create(:commit, project: project)
    commit.keys = [key1, key2]
    FactoryBot.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', source_copy: key1.source_copy, copy: "translated1"

    io = StringIO.new
    Exporter::Yaml.new(commit).export(io, Locale.from_rfc5646('fr'))
    expect(io.string).to eql(<<~YAML)
        ---
        fr:
          test1: translated1
    YAML
  end

  describe ".valid?" do
    it "should return true for a syntactically valid YAML hash" do
      expect(Exporter::Yaml.valid?(<<-YAML)).to be_truthy
---
ja-JP:
  different: Different (ja-JP)
  same: Same (ja)
      YAML
    end

    it "should return false for a different YAML object" do
      expect(Exporter::Yaml.valid?(<<-YAML)).to be_falsey
---
- 1
- 2
      YAML
    end

    it "should return false for a syntactically invalid YANL file" do
      expect(Exporter::Yaml.valid?(<<-YAML)).to be_falsey
---
foo: foo: foo
      YAML
    end

    it "should return false for an empty file" do
      expect(Exporter::Yaml.valid?('')).to be_falsey
    end
  end
end
