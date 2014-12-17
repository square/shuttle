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

describe ArticleAndCommitNotApprovedTranslationStats do
  before :each do
    Article.any_instance.stub(:import!) # prevent auto imports
  end

  context "[Commit]" do
    describe "#item_stat" do
      it "calculates stats for only required translations of each commit" do
        # setup project1 and commit1
        project1 = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true, 'de' => true, 'ja' => true, 'es' => false})

        key1 = FactoryGirl.create(:key, project: project1)
        FactoryGirl.create :translation, key: key1, rfc5646_locale: 'fr', source_copy: "hello foo bar", approved: nil,   copy: nil    # new
        FactoryGirl.create :translation, key: key1, rfc5646_locale: 'de', source_copy: "hello foo bar", approved: nil,   copy: nil    # new
        FactoryGirl.create :translation, key: key1, rfc5646_locale: 'ja', source_copy: "hello foo bar", approved: nil,   copy: "fake" # pending
        FactoryGirl.create :translation, key: key1, rfc5646_locale: 'es', source_copy: "hello foo bar", approved: false, copy: "fake" # pending (rejected)
        FactoryGirl.create :translation, key: key1, rfc5646_locale: 'tr', source_copy: "hello foo bar", approved: nil,   copy: "fake" # pending

        key2 = FactoryGirl.create(:key, project: project1)
        FactoryGirl.create :translation, key: key2, rfc5646_locale: 'fr', source_copy: "hello foo bar", approved: true, copy: "fake" # approved
        FactoryGirl.create :translation, key: key2, rfc5646_locale: 'de', source_copy: "hello foo bar", approved: nil,  copy: nil    # new
        FactoryGirl.create :translation, key: key2, rfc5646_locale: 'ja', source_copy: "hello foo bar", approved: nil,  copy: nil    # new
        FactoryGirl.create :translation, key: key2, rfc5646_locale: 'es', source_copy: "hello foo bar", approved: nil,  copy: "fake" # pending
        FactoryGirl.create :translation, key: key2, rfc5646_locale: 'tr', source_copy: "hello foo bar", approved: nil,  copy: nil    # new

        commit1 = FactoryGirl.create(:commit, project: project1)
        commit1.keys = [key1, key2]

        # setup project2 and commit2
        project2 = FactoryGirl.create(:project, targeted_rfc5646_locales: {'ja' => true, 'es' => false})

        key3 = FactoryGirl.create(:key, project: project2)
        FactoryGirl.create :translation, key: key3, rfc5646_locale: 'ja', source_copy: "hello foo bar", approved: nil, copy: nil # new
        FactoryGirl.create :translation, key: key3, rfc5646_locale: 'es', source_copy: "hello foo bar", approved: nil, copy: nil # new
        FactoryGirl.create :translation, key: key3, rfc5646_locale: 'tr', source_copy: "hello foo bar", approved: nil, copy: nil # new

        commit2 = FactoryGirl.create(:commit, project: project2)
        commit2.keys = [key3]

        #---------------------------------------------------------------------------------------------------------------

        # Tests without locales
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit1, commit2], [], [])
        expect(stats.item_stat(commit1, :translations, :new)).to eql(4)
        expect(stats.item_stat(commit1, :translations, :pending)).to eql(1)
        expect(stats.item_stat(commit1, :words, :new)).to eql(12)
        expect(stats.item_stat(commit1, :words, :pending)).to eql(3)
        expect(stats.item_stat(commit2, :translations, :new)).to eql(1)
        expect(stats.item_stat(commit2, :translations, :pending)).to eql(0)
        expect(stats.item_stat(commit2, :words, :new)).to eql(3)
        expect(stats.item_stat(commit2, :words, :pending)).to eql(0)

        # Tests with a single (required for commit1) locale: 'fr'
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit1, commit2], [], %w(fr).map { |x| Locale.from_rfc5646(x) } )
        expect(stats.item_stat(commit1, :translations, :new)).to eql(1)
        expect(stats.item_stat(commit1, :translations, :pending)).to eql(0)
        expect(stats.item_stat(commit1, :words, :new)).to eql(3)
        expect(stats.item_stat(commit1, :words, :pending)).to eql(0)

        # Tests with a single (required for commit1) locale: 'de'
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit1, commit2], [], %w(de).map { |x| Locale.from_rfc5646(x) } )
        expect(stats.item_stat(commit1, :translations, :new)).to eql(2)
        expect(stats.item_stat(commit1, :translations, :pending)).to eql(0)
        expect(stats.item_stat(commit1, :words, :new)).to eql(6)
        expect(stats.item_stat(commit1, :words, :pending)).to eql(0)

        # Tests with a single (optional for commit1) locale: 'es'
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit1, commit2], [], %w(es).map { |x| Locale.from_rfc5646(x) } )
        expect(stats.item_stat(commit1, :translations, :new)).to eql(0)
        expect(stats.item_stat(commit1, :translations, :pending)).to eql(2)
        expect(stats.item_stat(commit1, :words, :new)).to eql(0)
        expect(stats.item_stat(commit1, :words, :pending)).to eql(6)

        # Tests with a single (random) locale: 'tr'
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit1, commit2], [], %w(tr).map { |x| Locale.from_rfc5646(x) } )
        expect(stats.item_stat(commit1, :translations, :new)).to eql(0) # should discard translations in 'tr' because 'tr' is not a targeted locale
        expect(stats.item_stat(commit1, :translations, :pending)).to eql(0)
        expect(stats.item_stat(commit1, :words, :new)).to eql(0)
        expect(stats.item_stat(commit1, :words, :pending)).to eql(0)

        # Tests with a two locales (1 required, 1 optional): 'ja', 'es'
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit1, commit2], [], %w(ja es).map { |x| Locale.from_rfc5646(x) } )
        expect(stats.item_stat(commit1, :translations, :new)).to eql(1)
        expect(stats.item_stat(commit1, :translations, :pending)).to eql(3)
        expect(stats.item_stat(commit1, :words, :new)).to eql(3)
        expect(stats.item_stat(commit1, :words, :pending)).to eql(9)
        expect(stats.item_stat(commit2, :translations, :new)).to eql(2)
        expect(stats.item_stat(commit2, :translations, :pending)).to eql(0)
        expect(stats.item_stat(commit2, :words, :new)).to eql(6)
        expect(stats.item_stat(commit2, :words, :pending)).to eql(0)
      end

      it "should memoize the stats hash on initialize so that it doesn't query the db later" do
        project = FactoryGirl.create(:project)
        commit = FactoryGirl.create(:commit, project: project)
        key = FactoryGirl.create(:key, project: project)
        commit.keys << key
        translation = FactoryGirl.create(:translation, key: key)

        ArticleAndCommitNotApprovedTranslationStats.any_instance.should_receive(:commit_translation_groups_with_stats).and_call_original
        stats = ArticleAndCommitNotApprovedTranslationStats.new([commit], [], [])
        expect(stats).to_not receive(:commit_translation_groups_with_stats)
        stats.item_stat(commit, :translations, :new)
      end
    end
  end

  context "[Article]" do
    describe "#item_stat" do
      it "calculates translation stats for Article" do
        article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'de' => true, 'es' => true, 'ja' => true })
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, section: section, index_in_section: 0)
        FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', source_copy: "hello world", approved: true,  copy: "abc") # approved
        FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'de', source_copy: "hello world", approved: nil,   copy: nil)   # new
        FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'es', source_copy: "hello world", approved: nil,   copy: "abc") # pending
        FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'ja', source_copy: "hello world", approved: false, copy: "abc") # pending

        stats = ArticleAndCommitNotApprovedTranslationStats.new([], [article], [])
        expect(stats.item_stat(article, :translations, :new)).to eql(1)
        expect(stats.item_stat(article, :translations, :pending)).to eql(2)
        expect(stats.item_stat(article, :words, :new)).to eql(2)
        expect(stats.item_stat(article, :words, :pending)).to eql(4)
      end

      it "calculates stats for Article's required locales if no locales are inputted" do
        article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'de' => true })
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, section: section, index_in_section: 0)
        FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil)
        FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'es', approved: nil, copy: nil) # not in one of required locales

        stats = ArticleAndCommitNotApprovedTranslationStats.new([], [article], [])
        expect(stats.item_stat(article, :translations, :new)).to eql(1)
      end

      it "doesn't calculate stats for translations of inactive articles" do
        article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'de' => true, 'es' => true })
        section = FactoryGirl.create(:section, article: article, active: false)
        key = FactoryGirl.create(:key, section: section, index_in_section: 0)

        t1 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil)
        t2 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'de', approved: nil, copy: 'abc')
        t3 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'es', approved: false, copy: 'abc')

        stats = ArticleAndCommitNotApprovedTranslationStats.new([], [article], %w(fr de es).map { |l| Locale.from_rfc5646(l) })
        expect(stats.item_stat(article, :translations, :new)).to eql(0)
        expect(stats.item_stat(article, :translations, :pending)).to eql(0)
        expect(stats.item_stat(article, :words, :new)).to eql(0)
        expect(stats.item_stat(article, :words, :pending)).to eql(0)
      end

      it "doesn't calculate stats for translations of inactive keys" do
        article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'de' => true, 'es' => true })
        section = FactoryGirl.create(:section, article: article, active: true)
        key = FactoryGirl.create(:key, section: section, index_in_section: nil)

        t1 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil)
        t2 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'de', approved: nil, copy: 'abc')
        t3 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'es', approved: false, copy: 'abc')

        stats = ArticleAndCommitNotApprovedTranslationStats.new([], [article], %w(fr de es).map { |l| Locale.from_rfc5646(l) })
        expect(stats.item_stat(article, :translations, :new)).to eql(0)
        expect(stats.item_stat(article, :translations, :pending)).to eql(0)
        expect(stats.item_stat(article, :words, :new)).to eql(0)
        expect(stats.item_stat(article, :words, :pending)).to eql(0)
      end

      it "should memoize the stats hash on initialize so that it doesn't query the db later" do
        project = FactoryGirl.create(:project)
        article = FactoryGirl.create(:article, project: project)
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, project: project, section: section, index_in_section: 0)
        translation = FactoryGirl.create(:translation, key: key)

        ArticleAndCommitNotApprovedTranslationStats.any_instance.should_receive(:article_translation_groups_with_stats).and_call_original
        stats = ArticleAndCommitNotApprovedTranslationStats.new([], [article], [])
        expect(stats).to_not receive(:article_translation_groups_with_stats)
        stats.item_stat(article, :translations, :new)
      end
    end
  end
end
