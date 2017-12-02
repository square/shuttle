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

RSpec.describe Exporter::EmberES6Module do
  let(:source_locale) { Locale.from_rfc5646('en-US') }
  let(:target_locale) { Locale.from_rfc5646('de-DE') }
  let(:project) { FactoryBot.create(:project) }
  let(:commit) { FactoryBot.create(:commit, project: project) }

  before do
    marta1      = FactoryBot.create(:key,
                                     project: project,
                                     key:     "dialogue.marta[1]")
    marta2      = FactoryBot.create(:key,
                                     project: project,
                                     key:     "dialogue.marta[2]")
    gob1        = FactoryBot.create(:key,
                                     project: project,
                                     key:     "dialogue.gob[1]")
    gob2        = FactoryBot.create(:key,
                                     project: project,
                                     key:     "dialogue.gob[2]")
    commit.keys = [marta1, gob1, marta2, gob2]

    FactoryBot.create :translation,
                       key:           marta1,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "Te Quiero.",
                       copy:          "Te Quiero."
    FactoryBot.create :translation,
                       key:           gob1,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "English, please.",
                       copy:          "Deutsch, bitte."
    FactoryBot.create :translation,
                       key:           marta2,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "I love you.",
                       copy:          "Ich liebe dich."
    FactoryBot.create :translation,
                       key:           gob2,
                       source_locale: source_locale,
                       locale:        target_locale,
                       source_copy:   "Great. Now I'm late for work.",
                       copy:          "Toll. Jetzt bin ich spät zur Arbeit."
  end

  subject do
    StringIO.new.tap do |io|
      Exporter::EmberES6Module.new(commit).export(io, target_locale)
    end.string
  end

  it "should output translations in JavaScript format" do
    expect(subject).to eql(<<-JS)
export default {
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
export default {
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

      same         = FactoryBot.create(:key, project: project, key: 'same')
      different    = FactoryBot.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        source_locale,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        source_locale,
                         source_copy:   "Different",
                         copy:          "Different"
      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        en_CA,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        en_CA,
                         source_copy:   "Different",
                         copy:          "Different, eh"

      io = StringIO.new
      Exporter::EmberES6Module.new(commit).export(io, en_CA)
      expect(io.string).to eql(<<-JS)
export default {
  "different": "Different, eh"
};
      JS
    end

    it "should not de-dupe ja translations from en" do
      ja = Locale.from_rfc5646('ja')

      same         = FactoryBot.create(:key, project: project, key: 'same')
      different    = FactoryBot.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "異なる"

      io = StringIO.new
      Exporter::EmberES6Module.new(commit).export(io, ja)
      expect(io.string).to eql(<<-JS)
export default {
  "different": "異なる",
  "same": "Same"
};
      JS
    end

    it "should de-dupe ja-JP translations from ja if ja is a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      project.update_attribute :locale_requirements, source_locale => true, ja => true, ja_JP => true

      same         = FactoryBot.create(:key, project: project, key: 'same')
      different    = FactoryBot.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::EmberES6Module.new(commit).export(io, ja_JP)
      expect(io.string).to eql(<<-JS)
export default {
  "different": "Different (ja-JP)"
};
      JS
    end

    it "should not de-dupe ja-JP translations from ja if ja is not a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      project.update_attribute :locale_requirements, source_locale => true, ja => false, ja_JP => true

      same         = FactoryBot.create(:key, project: project, key: 'same')
      different    = FactoryBot.create(:key, project: project, key: 'different')
      commit.keys = [same, different]

      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryBot.create :translation,
                         key:           same,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryBot.create :translation,
                         key:           different,
                         source_locale: source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::EmberES6Module.new(commit).export(io, ja_JP)
      expect(io.string).to eql(<<-JS)
export default {
  "different": "Different (ja-JP)",
  "same": "Same (ja)"
};
      JS
    end
  end
end
