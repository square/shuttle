# Copyright 2016-2017 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicabcle law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'rails_helper'

RSpec.describe FuzzyMatchTranslationsFinder do
  # some integration tests exist in translation_controller_spec.rb

  describe "#top_fuzzy_match_percentage" do
    it "should return the top fuzzy match for a given translation" do
      source_copy = "yes"

      # create a translation that will be used for lookup for tm_match
      FactoryBot.create(:translation, copy: "oui", source_copy: source_copy, approved: true, translated: true, rfc5646_locale: 'fr')

      # finding the fuzzy match for a translation requires elasticsearch, update the index since we just created a translation
      TranslationsIndex.reset!

      translation = FactoryBot.build(:translation, source_copy: source_copy, rfc5646_locale: 'fr')
      finder = FuzzyMatchTranslationsFinder.new(source_copy, translation)
      expect(finder.top_fuzzy_match_percentage).to eq 100.0
    end

    it "should return 0.0 if there isn't any matches" do
      # there are no translation in the database, so there shouldn't be a match
      translation = FactoryBot.build(:translation, source_copy: 'yes', rfc5646_locale: 'fr')
      finder = FuzzyMatchTranslationsFinder.new('yes', translation)
      expect(finder.top_fuzzy_match_percentage).to eq 0.0
    end

    it "should return 0.0 if the top fuzzy match is < 60%" do
      # create a translation that will be used for lookup for tm_match
      FactoryBot.create(:translation, copy: "oui monsieur ", source_copy: 'yes sir', approved: true, translated: true, rfc5646_locale: 'fr')

      # finding the fuzzy match for a translation requires elasticsearch, update the index since we just created a translation
      TranslationsIndex.reset!

      # create a translation that will matches the above one with 57%
      translation = FactoryBot.build(:translation, source_copy: 'yes madam', rfc5646_locale: 'fr')
      finder = FuzzyMatchTranslationsFinder.new('yes', translation)
      expect(finder.top_fuzzy_match_percentage).to eq 0.0
    end
  end
end
