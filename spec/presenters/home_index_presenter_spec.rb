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

describe HomeIndexPresenter do
  describe "#commit_stat" do
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
      presenter = HomeIndexPresenter.new([commit1, commit2], [])
      expect(presenter.commit_stat(commit1, :translations, :new)).to eql(4)
      expect(presenter.commit_stat(commit1, :translations, :pending)).to eql(1)
      expect(presenter.commit_stat(commit1, :words, :new)).to eql(12)
      expect(presenter.commit_stat(commit1, :words, :pending)).to eql(3)
      expect(presenter.commit_stat(commit2, :translations, :new)).to eql(1)
      expect(presenter.commit_stat(commit2, :translations, :pending)).to eql(0)
      expect(presenter.commit_stat(commit2, :words, :new)).to eql(3)
      expect(presenter.commit_stat(commit2, :words, :pending)).to eql(0)

      # Tests with a single (required for commit1) locale: 'fr'
      presenter = HomeIndexPresenter.new([commit1, commit2], %w(fr).map { |x| Locale.from_rfc5646(x) } )
      expect(presenter.commit_stat(commit1, :translations, :new)).to eql(1)
      expect(presenter.commit_stat(commit1, :translations, :pending)).to eql(0)
      expect(presenter.commit_stat(commit1, :words, :new)).to eql(3)
      expect(presenter.commit_stat(commit1, :words, :pending)).to eql(0)

      # Tests with a single (required for commit1) locale: 'de'
      presenter = HomeIndexPresenter.new([commit1, commit2], %w(de).map { |x| Locale.from_rfc5646(x) } )
      expect(presenter.commit_stat(commit1, :translations, :new)).to eql(2)
      expect(presenter.commit_stat(commit1, :translations, :pending)).to eql(0)
      expect(presenter.commit_stat(commit1, :words, :new)).to eql(6)
      expect(presenter.commit_stat(commit1, :words, :pending)).to eql(0)

      # Tests with a single (optional for commit1) locale: 'es'
      presenter = HomeIndexPresenter.new([commit1, commit2], %w(es).map { |x| Locale.from_rfc5646(x) } )
      expect(presenter.commit_stat(commit1, :translations, :new)).to eql(0)
      expect(presenter.commit_stat(commit1, :translations, :pending)).to eql(2)
      expect(presenter.commit_stat(commit1, :words, :new)).to eql(0)
      expect(presenter.commit_stat(commit1, :words, :pending)).to eql(6)

      # Tests with a single (random) locale: 'tr'
      presenter = HomeIndexPresenter.new([commit1, commit2], %w(tr).map { |x| Locale.from_rfc5646(x) } )
      expect(presenter.commit_stat(commit1, :translations, :new)).to eql(0) # should discard translations in 'tr' because 'tr' is not a targeted locale
      expect(presenter.commit_stat(commit1, :translations, :pending)).to eql(0)
      expect(presenter.commit_stat(commit1, :words, :new)).to eql(0)
      expect(presenter.commit_stat(commit1, :words, :pending)).to eql(0)

      # Tests with a two locales (1 required, 1 optional): 'ja', 'es'
      presenter = HomeIndexPresenter.new([commit1, commit2], %w(ja es).map { |x| Locale.from_rfc5646(x) } )
      expect(presenter.commit_stat(commit1, :translations, :new)).to eql(1)
      expect(presenter.commit_stat(commit1, :translations, :pending)).to eql(3)
      expect(presenter.commit_stat(commit1, :words, :new)).to eql(3)
      expect(presenter.commit_stat(commit1, :words, :pending)).to eql(9)
      expect(presenter.commit_stat(commit2, :translations, :new)).to eql(2)
      expect(presenter.commit_stat(commit2, :translations, :pending)).to eql(0)
      expect(presenter.commit_stat(commit2, :words, :new)).to eql(6)
      expect(presenter.commit_stat(commit2, :words, :pending)).to eql(0)
    end

    it "should memoize the stats hash so that in the second try, it shouldn't query the db" do
      project = FactoryGirl.create(:project)
      key = FactoryGirl.create(:key, project: project)
      translation = FactoryGirl.create(:translation, key: key)
      commit = FactoryGirl.create(:commit, project: project)
      commit.keys << key
      presenter = HomeIndexPresenter.new([commit], [])

      expect(presenter).to receive(:translation_groups_with_stats).and_call_original
      presenter.commit_stat(commit, :translations, :new)
      expect(presenter).to_not receive(:translation_groups_with_stats)
      presenter.commit_stat(commit, :translations, :pending)
    end
  end
end
