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

describe Exporter::EmberIntlJSON do
  let(:source_locale) { Locale.from_rfc5646('en-US') }
  let(:target_locale) { Locale.from_rfc5646('de-DE') }
  let(:project) { FactoryGirl.create(:project) }
  let(:commit) { FactoryGirl.create(:commit, project: project) }

  before do
    root      = FactoryGirl.create(:key,
                                   project: project,
                                   key:     "root")
    nested1   = FactoryGirl.create(:key,
                                   project: project,
                                   key:     "nested.one")
    nested2   = FactoryGirl.create(:key,
                                   project: project,
                                   key:     "nested.two")
    commit.keys = [root, nested1, nested2]

    FactoryGirl.create :translation,
                       key:           root,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "Te Quiero.",
                       copy:          "Te Quiero."
    FactoryGirl.create :translation,
                       key:           nested1,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "English, please.",
                       copy:          "Deutsch, bitte."
    FactoryGirl.create :translation,
                       key:           nested2,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "I love you.",
                       copy:          "Ich liebe dich."
  end

  subject do
    StringIO.new.tap do |io|
      Exporter::EmberIntlJSON.new(commit).export(io, target_locale)
    end.string
  end

  it "should output translations in YAML format" do
    expect(subject).to eql(<<-JSON)
{
  "nested": {
    "one": "Deutsch, bitte.",
    "two": "Ich liebe dich."
  },
  "root": "Te Quiero."
}
    JSON
  end

  context "when the target locale is a base locale" do
    let(:target_locale) { Locale.from_rfc5646('de') }

    it "should output translations in YAML format" do
      expect(subject).to eql(<<-JSON)
{
  "nested": {
    "one": "Deutsch, bitte.",
    "two": "Ich liebe dich."
  },
  "root": "Te Quiero."
}
      JSON
    end
  end

  context "[deduping]" do
    it "should de-dupe en-CA translations from the base locale" do
      en_CA = Locale.from_rfc5646('en-CA')

      same         = FactoryGirl.create(:key, project: project, key: 'same')
      different    = FactoryGirl.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        source_locale,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        source_locale,
                         source_copy:   "Different",
                         copy:          "Different"
      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        en_CA,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        en_CA,
                         source_copy:   "Different",
                         copy:          "Different, eh"

      io = StringIO.new
      Exporter::EmberIntlJSON.new(commit).export(io, en_CA)
      expect(io.string).to eql(<<-JSON)
{
  "different": "Different, eh"
}
      JSON
    end

    it "should not de-dupe ja translations from en" do
      ja = Locale.from_rfc5646('ja')

      same         = FactoryGirl.create(:key, project: project, key: 'same')
      different    = FactoryGirl.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"

      io = StringIO.new
      Exporter::EmberIntlJSON.new(commit).export(io, ja)
      expect(io.string).to eql(<<-JSON)
{
  "different": "Different (ja)",
  "same": "Same"
}
      JSON
    end

    it "should de-dupe ja-JP translations from ja if ja is a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      project.update_attribute :locale_requirements, source_locale => true, ja => true, ja_JP => true

      same         = FactoryGirl.create(:key, project: project, key: 'same')
      different    = FactoryGirl.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::EmberIntlJSON.new(commit).export(io, ja_JP)
      expect(io.string).to eql(<<-JSON)
{
  "different": "Different (ja-JP)"
}
      JSON
    end

    it "should not de-dupe ja-JP translations from ja if ja is not a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      project.update_attribute :locale_requirements, source_locale => true, ja => false, ja_JP => true

      same         = FactoryGirl.create(:key, project: project, key: 'same')
      different    = FactoryGirl.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::EmberIntlJSON.new(commit).export(io, ja_JP)
      expect(io.string).to eql(<<-JSON)
{
  "different": "Different (ja-JP)",
  "same": "Same (ja)"
}
      JSON
    end
  end

  describe ".valid?" do
    it "should return true for a valid JSON file" do
      expect(Exporter::EmberIntlJSON.valid?(<<-JSON)).to be_truthy
{
  "different": "Different (ja-JP)",
  "same": "Same (ja)"
}
      JSON
    end

    it "should return false for a syntactically invalid JSON file" do
      expect(Exporter::EmberIntlJSON.valid?('NOT REAL FILE')).to be_falsey
    end

    it "should return false for an empty JSON file" do
      expect(Exporter::EmberIntlJSON.valid?('')).to be_falsey
    end
  end
end
