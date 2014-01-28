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

describe TranslationUnit do
  describe "#validations" do
    it "should require that the source and target locales be different" do
      tu = FactoryGirl.build(:translation_unit, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      expect(tu).not_to be_valid
      expect(tu.errors[:rfc5646_locale]).to eql(['invalid'])
    end
  end

  describe ".exact_matches" do
    before(:all) do
      @unit = FactoryGirl.create(:translation_unit,
                                 source_copy:           'something in english',
                                 copy:                  'etwas auf deutsch',
                                 source_rfc5646_locale: 'en',
                                 rfc5646_locale:        'de')
    end

    it "should return a 100%-matched translation memory unit" do
      trans = FactoryGirl.build(:translation,
                                source_copy:           'something in english',
                                source_rfc5646_locale: 'en',
                                rfc5646_locale:        'de')
      expect(TranslationUnit.exact_matches(trans).first).to eql(@unit)
    end

    it "should return nil if the source copy doesn't match" do
      trans = FactoryGirl.build(:translation,
                                source_copy:           'something else in english',
                                source_rfc5646_locale: 'en',
                                rfc5646_locale:        'de')
      expect(TranslationUnit.exact_matches(trans)).to be_empty
    end

    it "should return nil if the locale doesn't match" do
      trans = FactoryGirl.build(:translation,
                                source_copy:           'something in english',
                                source_rfc5646_locale: 'en-US',
                                rfc5646_locale:        'de')
      expect(TranslationUnit.exact_matches(trans)).to be_empty
    end

    it "should return a match if using a matching override locale" do
      trans = FactoryGirl.build(:translation,
                                source_copy:           'something in english',
                                source_rfc5646_locale: 'en',
                                rfc5646_locale:        'de-DE')
      expect(TranslationUnit.exact_matches(trans, Locale.from_rfc5646('de')).first).to eql(@unit)
    end

    it "should return nil if the source locale doesn't match" do
      trans = FactoryGirl.build(:translation,
                                source_copy:           'something in english',
                                source_rfc5646_locale: 'en',
                                rfc5646_locale:        'de-DE')
      expect(TranslationUnit.exact_matches(trans)).to be_empty
    end
  end

  describe ".store" do
    before :all do
      @translation = FactoryGirl.build(:translation, source_rfc5646_locale: 'en', rfc5646_locale: 'de', approved: true)
    end

    it "should create a new translation memory unit for the translation" do
      TranslationUnit.store @translation
      expect(TranslationUnit.source_copy_matches(@translation.source_copy).where(
          rfc5646_locale:        @translation.locale.rfc5646,
          source_rfc5646_locale: @translation.source_locale.rfc5646
      ).exists?).to be_true
    end

    it "should update an existing translation memory unit" do
      TranslationUnit.store @translation
      expect(TranslationUnit.source_copy_matches(@translation.source_copy).where(
          rfc5646_locale:        @translation.locale.rfc5646,
          source_rfc5646_locale: @translation.source_locale.rfc5646
      ).count).to eql(1)

      TranslationUnit.store @translation
      expect(TranslationUnit.source_copy_matches(@translation.source_copy).where(
          rfc5646_locale:        @translation.locale.rfc5646,
          source_rfc5646_locale: @translation.source_locale.rfc5646
      ).count).to eql(1)
    end

    it "should not create a translation memory for an unapproved translation" do
      @translation.approved = false
      TranslationUnit.store @translation
      expect(TranslationUnit.source_copy_matches(@translation.source_copy).where(
          rfc5646_locale:        @translation.locale.rfc5646,
          source_rfc5646_locale: @translation.source_locale.rfc5646
      ).exists?).to be_false
    end

    it "should not create a translation memory unit for a base translation" do
      @translation.rfc5646_locale = 'en'
      TranslationUnit.store @translation
      expect(TranslationUnit.source_copy_matches(@translation.source_copy).where(
          rfc5646_locale:        @translation.locale.rfc5646,
          source_rfc5646_locale: @translation.source_locale.rfc5646
      ).exists?).to be_false
    end
  end
end
