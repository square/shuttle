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

describe ArticleOrCommitStats do
  describe "#fetch_stat" do
    before :each do
      @commit = FactoryGirl.build(:commit)
      @commit.stub(:stats).and_return( {
                                          approved: { translations_count: 1, words_count: 2 },
                                          pending: { translations_count: 1, words_count: 1 }
                                       })
    end

    it "returns the default value if state is not in stats hash" do
      expect(@commit.send :fetch_stat, [], :new, :translations_count, :doesnt_exist).to eql(:doesnt_exist)
    end

    it "returns the default value if field is not in stats hash" do
      expect(@commit.send :fetch_stat, [], :approved, :fake_count).to eql(0)
    end

    it "returns the correct value if state and field exist in stats hash" do
      expect(@commit.send :fetch_stat, [], :approved, :words_count).to eql(2)
    end
  end

  context "[should recalculate article statistics correctly]" do
    def create_translations_for_active_keys(key1, key2)
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'en', source_rfc5646_locale: 'en', source_copy: "hello world", approved: true,  copy: "fake" # base translation
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'en', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: true,  copy: "fake" # base translation
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', source_copy: "hello world", approved: true,  copy: "fake" # approved
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: true,  copy: "fake" # approved
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'de', source_rfc5646_locale: 'en', source_copy: "hello world", approved: true,  copy: "fake" # approved
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'de', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: false, copy: "fake" # pending (rejected)
      FactoryGirl.create :translation, key: key1, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', source_copy: "hello world", approved: nil,   copy: "fake" # pending
      FactoryGirl.create :translation, key: key2, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: nil,   copy: nil    # not-translated
    end

    def expectations_without_locales(item)
      expect(item.stats).to eql({
                                        approved: { translations_count: 2, words_count: 3 },
                                        pending: { translations_count: 1, words_count: 2 },
                                        new: { translations_count: 1, words_count: 1 },
                                    })

      expect(item.strings_total).to eql(2)
      expect(item.translations_done).to eql(2)
      expect(item.translations_not_done).to eql(2)
      expect(item.translations_pending).to eql(1)
      expect(item.translations_new).to eql(1)
      expect(item.translations_total).to eql(4)
      expect(item.words_pending).to eql(2)
      expect(item.words_new).to eql(1)
    end

    def expectations_with_locales(item)
      expect(item.translations_done(*%w(fr).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(2)
      expect(item.translations_pending(*%w(ja de).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(2)
      expect(item.translations_new(*%w(ja).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(1)
      expect(item.translations_not_done(*%w(ja fr de).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(3)
      expect(item.translations_total(*%w(fr de ja tr).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(6)
      expect(item.translations_total(*%w(tr).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(0)
      expect(item.words_pending(*%w(fr de ja).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(3)
      expect(item.words_new(*%w(fr de ja).map { |rfc5646| Locale.from_rfc5646(rfc5646) } )).to eql(1)
    end

    it "should calculate article statistics correctly" do
      Article.any_instance.stub(:import!)
      @article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true, 'de' => false, 'ja' => true})
      active_section   = FactoryGirl.create(:section, article: @article)
      inactive_section = FactoryGirl.create(:section, article: @article, active: false)

      key1 = FactoryGirl.create(:key, section: active_section, index_in_section: 0)
      key2 = FactoryGirl.create(:key, section: active_section, index_in_section: 1)
      key3 = FactoryGirl.create(:key, section: active_section, index_in_section: nil) # key is inactive
      key4 = FactoryGirl.create(:key, section: inactive_section, index_in_section: 0) # section is inactive

      create_translations_for_active_keys(key1, key2)
      FactoryGirl.create :translation, key: key3, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', source_copy: "hello world", approved: nil,   copy: "fake" # pending
      FactoryGirl.create :translation, key: key4, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', source_copy: "whatsup",     approved: nil,   copy: nil    # not-translated

      expectations_without_locales(@article)
      expectations_with_locales(@article)
    end

    it "should recalculate Commit statistics correctly" do
      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true, 'de' => false, 'ja' => true})
      @commit = FactoryGirl.create(:commit, project: project)

      key1 = FactoryGirl.create(:key, project: project)
      key2 = FactoryGirl.create(:key, project: project)

      @commit.keys = [key1, key2]
      create_translations_for_active_keys(key1, key2)

      expectations_without_locales(@commit)
      expectations_with_locales(@commit)
    end
  end
end
