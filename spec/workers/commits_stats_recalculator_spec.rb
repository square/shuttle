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

describe CommitStatsRecalculator do
  before :all do
    # create a commit with 2 total strings, 8 total translations, 4 required
    # translations, and 2 required done translations

    project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'en' => true, 'fr' => true, 'de' => false, 'ja' => true})
    @commit = FactoryGirl.create(:commit, project: project)
    key1    = FactoryGirl.create(:key, project: project)
    key2    = FactoryGirl.create(:key, project: project)

    FactoryGirl.create :translation, key: key1, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true
    FactoryGirl.create :translation, key: key2, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true
    FactoryGirl.create :translation, key: key1, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: true
    FactoryGirl.create :translation, key: key2, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: false
    FactoryGirl.create :translation, key: key1, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true
    FactoryGirl.create :translation, key: key2, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true
    FactoryGirl.create :translation, key: key1, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: true
    FactoryGirl.create :translation, key: key2, rfc5646_locale: 'ja', source_rfc5646_locale: 'en', approved: nil

    @commit.keys = [key1, key2]
  end

  it "should recalculate commit statistics correctly" do
    Commit.flush_memoizations @commit
    CommitStatsRecalculator.new.perform(@commit.id)

    expect(@commit.reload.translations_total).to eql(4)
    expect(@commit.translations_done).to eql(2)
    expect(@commit.strings_total).to eql(2)
  end
end
