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

describe Exporter::Properties do
  before :each do
    @source_locale = Locale.from_rfc5646('en-US')
    @target_locale = Locale.from_rfc5646('de-DE')
    @project       = FactoryGirl.create(:project)
    @commit        = FactoryGirl.create(:commit, project: @project)

    marta1      = FactoryGirl.create(:key,
                                     project: @project,
                                     key:     "dialogue.marta[1]")
    marta2      = FactoryGirl.create(:key,
                                     project: @project,
                                     key:     "dialogue.marta[2]")
    gob1        = FactoryGirl.create(:key,
                                     project: @project,
                                     key:     "dialogue.gob[1]")
    gob2        = FactoryGirl.create(:key,
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

  it "should output translations in Java properties format" do
    io = StringIO.new
    Exporter::Properties.new(@commit).export(io, @target_locale)

    expect(io.string).to include(<<-EOS)
dialogue.gob[2]=Toll. Jetzt bin ich spät zur Arbeit.
    EOS
    expect(io.string).to include(<<-EOS)
dialogue.marta[2]=Ich liebe dich.
    EOS
    expect(io.string).to include(<<-EOS)
dialogue.gob[1]=Deutsch, bitte.
    EOS
    expect(io.string).to include(<<-EOS)
dialogue.marta[1]=Te Quiero.
    EOS
  end

  describe ".valid?" do
    it "should return true for a syntactically valid properties file" do
      expect(Exporter::Properties.valid?(<<-EOS)).to be_true
foo=bar
foo[1]=bar two.
      EOS
      expect(Exporter::Properties.valid?('a=b')).to be_true
      expect(Exporter::Properties.valid?('a\\=b=b\\=a')).to be_true
    end

    it "should return false for a syntactically invalid properties file" do
      expect(Exporter::Properties.valid?('foo=')).to be_false
      expect(Exporter::Properties.valid?('foo=foo=foo')).to be_false
      expect(Exporter::Properties.valid?('=foo')).to be_false
      expect(Exporter::Properties.valid?('hi!')).to be_false
      expect(Exporter::Properties.valid?("foo=\n=foo")).to be_false
    end

    it "should return false for an empty properties file" do
      expect(Exporter::Properties.valid?('')).to be_false
    end
  end
end
