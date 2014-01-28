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

describe Exporter::Ember do
  let(:source_locale) { Locale.from_rfc5646('en-US') }
  let(:target_locale) { Locale.from_rfc5646('de-DE') }
  let(:project) { FactoryGirl.create(:project) }
  let(:commit) { FactoryGirl.create(:commit, project: project) }

  before do
    marta1      = FactoryGirl.create(:key,
                                     project: project,
                                     key:     "dialogue.marta[1]")
    marta2      = FactoryGirl.create(:key,
                                     project: project,
                                     key:     "dialogue.marta[2]")
    gob1        = FactoryGirl.create(:key,
                                     project: project,
                                     key:     "dialogue.gob[1]")
    gob2        = FactoryGirl.create(:key,
                                     project: project,
                                     key:     "dialogue.gob[2]")
    commit.keys = [marta1, gob1, marta2, gob2]

    FactoryGirl.create :translation,
                       key:           marta1,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "Te Quiero.",
                       copy:          "Te Quiero."
    FactoryGirl.create :translation,
                       key:           gob1,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "English, please.",
                       copy:          "Deutsch, bitte."
    FactoryGirl.create :translation,
                       key:           marta2,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "I love you.",
                       copy:          "Ich liebe dich."
    FactoryGirl.create :translation,
                       key:           gob2,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "Great. Now I'm late for work.",
                       copy:          "Toll. Jetzt bin ich spät zur Arbeit."
  end

  subject do
    StringIO.new.tap do |io|
      Exporter::Ember.new(commit).export(io, target_locale)
    end.string
  end

  it "should output translations in JavaScript format" do
    expect(subject).to eql(<<-JS)
Ember.I18n.locales.translations["de-DE"] = {
  "dialogue": {
    "gob": [
      null,
      "Deutsch, bitte.",
      "Toll. Jetzt bin ich spät zur Arbeit."
    ],
    "marta": [
      null,
      "Te Quiero.",
      "Ich liebe dich."
    ]
  }
};
    JS
  end

  context "when the target locale is a base locale" do
    let(:target_locale) { Locale.from_rfc5646('de') }

    it "should output translations in JavaScript passing the default jshint checks" do
      expect(subject).to eql(<<-JS)
Ember.I18n.locales.translations.de = {
  "dialogue": {
    "gob": [
      null,
      "Deutsch, bitte.",
      "Toll. Jetzt bin ich spät zur Arbeit."
    ],
    "marta": [
      null,
      "Te Quiero.",
      "Ich liebe dich."
    ]
  }
};
      JS
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
      Exporter::Ember.new(commit).export(io, en_CA)
      expect(io.string).to eql(<<-JS)
Ember.I18n.locales.translations["en-CA"] = {
  "different": "Different, eh"
};
      JS
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
                         copy:          "異なる"

      io = StringIO.new
      Exporter::Ember.new(commit).export(io, ja)
      expect(io.string).to eql(<<-JS)
Ember.I18n.locales.translations.ja = {
  "different": "異なる",
  "same": "Same"
};
      JS
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
      Exporter::Ember.new(commit).export(io, ja_JP)
      expect(io.string).to eql(<<-JS)
Ember.I18n.locales.translations["ja-JP"] = {
  "different": "Different (ja-JP)"
};
      JS
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
      Exporter::Ember.new(commit).export(io, ja_JP)
      expect(io.string).to eql(<<-JS)
Ember.I18n.locales.translations["ja-JP"] = {
  "different": "Different (ja-JP)",
  "same": "Same (ja)"
};
      JS
    end
  end

  describe ".valid?" do
    it "should return true for a valid JS file" do
      expect(Exporter::Ember.valid?(<<-JS)).to be_true
Ember.I18n.locales.translations["ja-JP"] = {
  "different": "Different (ja-JP)",
  "same": "Same (ja)"
};
      JS
    end

    it "should return false for a syntactically invalid JS file" do
      expect(Exporter::Ember.valid?('wat?!')).to be_false
    end

    it "should return false for a semantically invalid JS file" do
      expect(Exporter::Ember.valid?('var foo=bar;')).to be_false
    end

    it "should return false for an empty JS file" do
      expect(Exporter::Ember.valid?('')).to be_false
    end
  end
end
