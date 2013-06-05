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

describe Locale do
  describe '.from_rfc5646' do
    it "should recognize a simple locale subtag" do
      locale = Locale.from_rfc5646('de')
      locale.iso639.should eql('de')
      locale.script.should be_nil
      locale.region.should be_nil
      locale.variants.should eql([])
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end

    it "should recognize a locale + script subtag" do
      locale = Locale.from_rfc5646('zh-Hant')
      locale.iso639.should eql('zh')
      locale.script.should eql('Hant')
      locale.region.should be_nil
      locale.variants.should eql([])
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end

    it "should recognize a an extended locale subtag" do
      locale = Locale.from_rfc5646('zh-cmn-Hans-CN')
      locale.iso639.should eql('zh')
      locale.script.should eql('Hans')
      locale.region.should eql('CN')
      locale.variants.should eql([])
      locale.extended_language.should eql('cmn')
      locale.extensions.should eql([])
    end

    it "should recognize a locale-script-region subtag" do
      locale = Locale.from_rfc5646('zh-Hans-CN')
      locale.iso639.should eql('zh')
      locale.script.should eql('Hans')
      locale.variants.should eql([])
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end

    it "should recognize a locale-variant subtag" do
      locale = Locale.from_rfc5646('sl-rozaj')
      locale.iso639.should eql('sl')
      locale.script.should be_nil
      locale.region.should be_nil
      locale.variants.should eql(%w(rozaj))
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end

    it "should recognize a locale-region-variant subtag" do
      locale = Locale.from_rfc5646('de-CH-1901')
      locale.iso639.should eql('de')
      locale.script.should be_nil
      locale.region.should eql('CH')
      locale.variants.should eql(%w(1901))
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end

    it "should recognize a locale-script-region-variant subtag" do
      locale = Locale.from_rfc5646('hy-Latn-IT-arevela')
      locale.iso639.should eql('hy')
      locale.script.should eql('Latn')
      locale.region.should eql('IT')
      locale.variants.should eql(%w(arevela))
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end

    it "should recognize a locale-region subtag" do
      locale = Locale.from_rfc5646('de-DE')
      locale.iso639.should eql('de')
      locale.script.should be_nil
      locale.region.should eql('DE')
      locale.variants.should eql([])
      locale.extended_language.should be_nil
      locale.extensions.should eql([])
    end
  end

  describe '#rfc5646' do
    it "should properly normalize locale component values" do
      Locale.from_rfc5646('hy-Latn-IT-arevela-x-foobar').rfc5646.should eql('hy-Latn-IT-arevela')
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
        Locale.from_rfc5646(subtag).name.should eql(name)
      end
    end
  end

  describe "#child_of?" do
    it "should claim that en-US is a child of en" do
      Locale.from_rfc5646('en-US').child_of?(Locale.from_rfc5646('en')).should be_true
    end

    it "should not claim that ja is a child of en" do
      Locale.from_rfc5646('ja').child_of?(Locale.from_rfc5646('en')).should be_false
    end

    it "should claim that zh-cmn-Hans-CN is a child of zh-CN" do
      Locale.from_rfc5646('zh-cmn-Hans-CN').child_of?(Locale.from_rfc5646('zh-CN')).should be_true
    end

    it "should not claim that zh-cmn-Hans-CN is a child of zh-yue-Hans" do
      Locale.from_rfc5646('zh-cmn-Hans-CN').child_of?(Locale.from_rfc5646('zh-yue-Hans')).should be_false
    end

    it "should claim that sl-rozaj-biske is a child of sl-rozaj" do
      Locale.from_rfc5646('sl-rozaj-biske').child_of?(Locale.from_rfc5646('sl-rozaj')).should be_true
    end

    it "should not claim that sl-rozaj-biske is a child of sl-nedis" do
      Locale.from_rfc5646('en-rozaj-biske').child_of?(Locale.from_rfc5646('sl-nedis')).should be_false
    end
  end
end
