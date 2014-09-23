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

describe CommitStats do
  describe "#recalculate_stats!" do
    before :each do
      # create a commit with 2 total strings, 8 total translations, 4 required
      # translations, and 2 done required translations

      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true, 'de' => false, 'ja' => true})
      @commit = FactoryGirl.create(:commit, project: project)
      key1 = FactoryGirl.create(:key, project: project)
      key2 = FactoryGirl.create(:key, project: project)

      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'en', source_rfc5646_locale: 'en', source_copy: "hello world", approved: true,  copy: "fake" # base translation
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'en', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: true,  copy: "fake" # base translation
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', source_copy: "hello world", approved: true,  copy: "fake" # approved
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: true,  copy: "fake" # approved
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'de', source_rfc5646_locale: 'en', source_copy: "hello world", approved: true,  copy: "fake" # approved
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'de', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: false, copy: "fake" # pending (rejected)
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', source_copy: "hello world", approved: nil,   copy: "fake" # pending
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: nil,   copy: nil    # not-translated

      @commit.keys = [key1, key2]
    end

    it "returns 0 for all stats whether locales are given or not if recalculate_stats! is not called yet (for ex: import not finished yet)" do
      expect(@commit.stats).to eql({})

      expect(@commit.strings_total).to eql(0)
      expect(@commit.translations_total).to eql(0)
      expect(@commit.translations_done).to eql(0)
      expect(@commit.translations_pending).to eql(0)
      expect(@commit.translations_new).to eql(0)
      expect(@commit.words_pending).to eql(0)
      expect(@commit.words_new).to eql(0)
      expect(@commit.translations_total(Locale.from_rfc5646('fr'))).to eql(0)
      expect(@commit.words_pending(Locale.from_rfc5646('tr'), Locale.from_rfc5646('de'))).to eql(0)
    end

    it "should recalculate commit statistics correctly" do
      @commit.recalculate_stats!
      expect(@commit.stats).to eql({ strings_total: 2,
                                     locale_specific:
                                         {
                                             'de' =>
                                                 {
                                                     approved: { translations_count: 1, words_count: 2 },
                                                     pending: { translations_count: 1, words_count: 1 }
                                                 },
                                             'fr' =>
                                                 {
                                                     approved: { translations_count: 2, words_count: 3 }
                                                 },
                                             'ja' =>
                                                 {
                                                     new: { translations_count: 1, words_count: 1 },
                                                     pending: { translations_count: 1, words_count: 2 }
                                                 }
                                         }
                                   })

      # without locales
      expect(@commit.strings_total).to eql(2)
      expect(@commit.translations_done).to eql(2)
      expect(@commit.translations_pending).to eql(1)
      expect(@commit.translations_new).to eql(1)
      expect(@commit.translations_total).to eql(4)
      expect(@commit.words_pending).to eql(2)
      expect(@commit.words_new).to eql(1)

      # with locales
      expect(@commit.translations_done(*%w(fr).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(2)
      expect(@commit.translations_pending(*%w(ja de).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(2)
      expect(@commit.translations_new(*%w(ja).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(1)
      expect(@commit.translations_total(*%w(fr de ja tr).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(6)
      expect(@commit.translations_total(*%w(tr).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(0)
      expect(@commit.words_pending(*%w(fr de ja).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(3)
      expect(@commit.words_new(*%w(fr de ja).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(1)
    end
  end

  describe "#fetch_stat" do
    before :each do
      @commit = FactoryGirl.build(:commit)
      @commit.stats = { strings_total: 2,
                        locale_specific:
                            {
                                'de' =>
                                    {
                                        approved: { translations_count: 1, words_count: 2 },
                                        pending: { translations_count: 1, words_count: 1 }
                                    }
                            }
                      }
    end

    it "returns the default value if stats is nil" do
      @commit.stats = nil
      expect(@commit.send :fetch_stat, :test, :doesnt_exist).to eql(:doesnt_exist)
    end

    it "returns the default value if args don't correspond to a valid value" do
      expect(@commit.send :fetch_stat, :locale_specific, 'tr', :approved, :words_count, :doesnt_exist).to eql(:doesnt_exist)
    end

    it "fetches correct value when a single argument is given" do
      expect(@commit.send :fetch_stat, :strings_total, :doesnt_exist).to eql(2)
    end

    it "fetches correct value when multiple arguments are given" do
      expect(@commit.send :fetch_stat, :locale_specific, 'de', :approved, :words_count, :doesnt_exist).to eql(2)
    end
  end
end
