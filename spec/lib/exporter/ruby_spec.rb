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

require 'spec_helper'

describe Exporter::Ruby do
  before :each do
    @source_locale = Locale.from_rfc5646('en-US')
    @target_locale = Locale.from_rfc5646('de-DE')
    @project       = FactoryGirl.create(:project)
    @commit        = FactoryGirl.create(:commit, project: @project)

    marta1       = FactoryGirl.create(:key,
                                      project: @project,
                                      key:     "dialogue.marta[1]")
    marta2       = FactoryGirl.create(:key,
                                      project: @project,
                                      key:     "dialogue.marta[2]")
    gob1         = FactoryGirl.create(:key,
                                      project: @project,
                                      key:     "dialogue.gob[1]")
    gob2         = FactoryGirl.create(:key,
                                      project: @project,
                                      key:     "dialogue.gob[2]")
    @commit.keys = [marta1, gob1, marta2, gob2]

    FactoryGirl.create :translation,
                       key:           marta1,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "Te Quiero.",
                       copy:          "Te Quiero."
    FactoryGirl.create :translation,
                       key:           gob1,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "English, please.",
                       copy:          "Deutsch, bitte."
    FactoryGirl.create :translation,
                       key:           marta2,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "I love you.",
                       copy:          "Ich liebe dich."
    FactoryGirl.create :translation,
                       key:           gob2,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "Great. Now I'm late for work.",
                       copy:          "Toll. Jetzt bin ich spät zur Arbeit."
  end

  it "should output translations in Ruby format" do
    io = StringIO.new
    Exporter::Ruby.new(@commit).export(io, @target_locale)
    expect(io.string).to eql(<<-RUBY)
{"de-DE"=>
  {"dialogue"=>
    {"gob"=>[nil, "Deutsch, bitte.", "Toll. Jetzt bin ich spät zur Arbeit."],
     "marta"=>[nil, "Te Quiero.", "Ich liebe dich."]}}}
    RUBY
  end

  context "[deduping]" do
    it "should not de-dupe ja translations from en" do
      ja = Locale.from_rfc5646('ja')

      same         = FactoryGirl.create(:key, project: @project, key: 'same')
      different    = FactoryGirl.create(:key, project: @project, key: 'different')
      @commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "異なる"
      io = StringIO.new
      Exporter::Ruby.new(@commit).export(io, ja)
      expect(io.string).to eql(<<-RUBY)
{"ja"=>{"different"=>"異なる", "same"=>"Same"}}
      RUBY
    end

    it "should de-dupe ja-JP translations from ja if ja is a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      @project.update_attribute :locale_requirements, @source_locale => true, ja => true, ja_JP => true

      same         = FactoryGirl.create(:key, project: @project, key: 'same')
      different    = FactoryGirl.create(:key, project: @project, key: 'different')
      @commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::Ruby.new(@commit).export(io, ja_JP)
      expect(io.string).to eql(<<-RUBY)
{"ja-JP"=>{"different"=>"Different (ja-JP)"}}
      RUBY
    end

    it "should not de-dupe ja-JP translations from ja if ja is not a required locale" do
      ja    = Locale.from_rfc5646('ja')
      ja_JP = Locale.from_rfc5646('ja-JP')
      @project.update_attribute :locale_requirements, @source_locale => true, ja => false, ja_JP => true

      same         = FactoryGirl.create(:key, project: @project, key: 'same')
      different    = FactoryGirl.create(:key, project: @project, key: 'different')
      @commit.keys = [same, different]

      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja,
                         source_copy:   "Different",
                         copy:          "Different (ja)"
      FactoryGirl.create :translation,
                         key:           same,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Same",
                         copy:          "Same (ja)"
      FactoryGirl.create :translation,
                         key:           different,
                         source_locale: @source_locale,
                         locale:        ja_JP,
                         source_copy:   "Different",
                         copy:          "Different (ja-JP)"

      io = StringIO.new
      Exporter::Ruby.new(@commit).export(io, ja_JP)
      expect(io.string).to eql(<<-RUBY)
{"ja-JP"=>{"different"=>"Different (ja-JP)", "same"=>"Same (ja)"}}
      RUBY
    end
  end

  describe ".valid?" do
    it "should return true for a valid Ruby hash" do
      expect(Exporter::Ruby.valid?(<<-RUBY)).to be_true
{"ja-JP"=>{"different"=>"Different (ja-JP)", "same"=>"Same (ja)"}}
      RUBY
    end

    it "should return false for another Ruby object" do
      expect(Exporter::Ruby.valid?('[1,2,3]')).to be_false
    end

    it "should return false for Ruby code that generates a runtime error" do
      expect(Exporter::Ruby.valid?('{"foo" => bar}')).to be_false
    end

    it "should return false for Ruby code that generates a syntax error" do
      expect(Exporter::Ruby.valid?('$!$*()%(@*&%@(*%^(')).to be_false
    end

    it "should return false for an empty file" do
      expect(Exporter::Ruby.valid?('')).to be_false
    end
  end
end
