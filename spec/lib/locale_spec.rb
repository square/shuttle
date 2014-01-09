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

describe Locale do
  describe '.from_rfc5646' do
    it "should recognize a simple locale subtag" do
      locale = Locale.from_rfc5646('de')
      expect(locale.iso639).to eql('de')
      expect(locale.script).to be_nil
      expect(locale.region).to be_nil
      expect(locale.variants).to eql([])
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end

    it "should recognize a locale + script subtag" do
      locale = Locale.from_rfc5646('zh-Hant')
      expect(locale.iso639).to eql('zh')
      expect(locale.script).to eql('Hant')
      expect(locale.region).to be_nil
      expect(locale.variants).to eql([])
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end

    it "should recognize a an extended locale subtag" do
      locale = Locale.from_rfc5646('zh-cmn-Hans-CN')
      expect(locale.iso639).to eql('zh')
      expect(locale.script).to eql('Hans')
      expect(locale.region).to eql('CN')
      expect(locale.variants).to eql([])
      expect(locale.extended_language).to eql('cmn')
      expect(locale.extensions).to eql([])
    end

    it "should recognize a locale-script-region subtag" do
      locale = Locale.from_rfc5646('zh-Hans-CN')
      expect(locale.iso639).to eql('zh')
      expect(locale.script).to eql('Hans')
      expect(locale.variants).to eql([])
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end

    it "should recognize a locale-variant subtag" do
      locale = Locale.from_rfc5646('sl-rozaj')
      expect(locale.iso639).to eql('sl')
      expect(locale.script).to be_nil
      expect(locale.region).to be_nil
      expect(locale.variants).to eql(%w(rozaj))
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end

    it "should recognize a locale-region-variant subtag" do
      locale = Locale.from_rfc5646('de-CH-1901')
      expect(locale.iso639).to eql('de')
      expect(locale.script).to be_nil
      expect(locale.region).to eql('CH')
      expect(locale.variants).to eql(%w(1901))
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end

    it "should recognize a locale-script-region-variant subtag" do
      locale = Locale.from_rfc5646('hy-Latn-IT-arevela')
      expect(locale.iso639).to eql('hy')
      expect(locale.script).to eql('Latn')
      expect(locale.region).to eql('IT')
      expect(locale.variants).to eql(%w(arevela))
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end

    it "should recognize a locale-region subtag" do
      locale = Locale.from_rfc5646('de-DE')
      expect(locale.iso639).to eql('de')
      expect(locale.script).to be_nil
      expect(locale.region).to eql('DE')
      expect(locale.variants).to eql([])
      expect(locale.extended_language).to be_nil
      expect(locale.extensions).to eql([])
    end
  end

  describe '#rfc5646' do
    it "should properly normalize locale component values" do
      expect(Locale.from_rfc5646('hy-Latn-IT-arevela-x-foobar').rfc5646).to eql('hy-Latn-IT-arevela')
    end
  end

  describe '#name' do
    it "should properly name all examples from the spec" do
      {
          'de'                    => 'German',
          'fr'                    => 'French',
          'ja'                    => 'Japanese',
          'zh-Hant'               => 'Chinese (Han (Traditional variant) orthography)',
          'zh-Hans'               => 'Chinese (Han (Simplified variant) orthography)',
          'sr-Cyrl'               => 'Serbian (Cyrillic orthography)',
          'sr-Latn'               => 'Serbian (Latin orthography)',
          'zh-cmn-Hans-CN'        => 'Mandarin Chinese (as spoken in China, Han (Simplified variant) orthography)',
          'cmn-Hans-CN'           => 'Mandarin Chinese (as spoken in China, Han (Simplified variant) orthography)',
          'zh-yue-HK'             => 'Yue Chinese (as spoken in Hong Kong)',
          'yue-HK'                => 'Yue Chinese (as spoken in Hong Kong)',
          'zh-Hans-CN'            => 'Chinese (as spoken in China, Han (Simplified variant) orthography)',
          'sr-Latn-RS'            => "Serbian (as spoken in Serbia, Latin orthography)",
          'sl-rozaj'              => 'Slovenian (Resian)',
          'sl-rozaj-biske'        => 'Slovenian (The San Giorgio dialect of Resian)',
          'sl-nedis'              => 'Slovenian (Natisone dialect)',
          'de-CH-1901'            => 'German (Traditional German orthography as spoken in Switzerland)',
          'sl-IT-nedis'           => 'Slovenian (Natisone dialect as spoken in Italy)',
          'hy-Latn-IT-arevela'    => 'Armenian (Eastern Armenian as spoken in Italy, Latin orthography)',
          'de-DE'                 => 'German (as spoken in Germany)',
          'en-US'                 => 'English (as spoken in United States)',
          'es-419'                => 'Spanish (as spoken in Latin America and the Caribbean)',
          'de-CH-x-phonebk'       => 'German (as spoken in Switzerland)',
          'az-Arab-x-AZE-derbend' => 'Azerbaijani (Arabic orthography)'
      }.each do |subtag, name|
        expect(Locale.from_rfc5646(subtag).name).to eql(name)
      end
    end
  end

  describe "#child_of?" do
    it "should claim that en-US is a child of en" do
      expect(Locale.from_rfc5646('en-US').child_of?(Locale.from_rfc5646('en'))).to be_true
    end

    it "should not claim that ja is a child of en" do
      expect(Locale.from_rfc5646('ja').child_of?(Locale.from_rfc5646('en'))).to be_false
    end

    it "should claim that zh-cmn-Hans-CN is a child of zh-CN" do
      expect(Locale.from_rfc5646('zh-cmn-Hans-CN').child_of?(Locale.from_rfc5646('zh-CN'))).to be_true
    end

    it "should not claim that zh-cmn-Hans-CN is a child of zh-yue-Hans" do
      expect(Locale.from_rfc5646('zh-cmn-Hans-CN').child_of?(Locale.from_rfc5646('zh-yue-Hans'))).to be_false
    end

    it "should claim that sl-rozaj-biske is a child of sl-rozaj" do
      expect(Locale.from_rfc5646('sl-rozaj-biske').child_of?(Locale.from_rfc5646('sl-rozaj'))).to be_true
    end

    it "should not claim that sl-rozaj-biske is a child of sl-nedis" do
      expect(Locale.from_rfc5646('en-rozaj-biske').child_of?(Locale.from_rfc5646('sl-nedis'))).to be_false
    end
  end
end
