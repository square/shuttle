# encoding: UTF-8

require 'spec_helper'

describe Exporter::NtYaml do
  before :all do
    @source_locale = Locale.from_rfc5646('en-US')
    @target_locale = Locale.from_rfc5646('es')
    @project       = FactoryGirl.create(:project)
    @commit        = FactoryGirl.create(:commit, project: @project)

    marta1      = FactoryGirl.create(:key,
                                     project: @project,
                                     source_copy: "a message",
                                     context: "somewhere"
                                    )
    marta2      = FactoryGirl.create(:key,
                                     project: @project,
                                     source_copy: "another message",
                                     context: "another place"
                                    )
    @commit.keys = [marta1, marta2]

    FactoryGirl.create(:translation,
                       key:           marta1,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "a message",
                       copy:          "un mensaje"
                      )
    FactoryGirl.create(:translation,
                       key:           marta2,
                       source_locale: @source_locale,
                       locale:        @target_locale,
                       source_copy:   "another message",
                       copy:          "un otro mensaje"
                      )
  end

  it "should output translations in YAML format" do
    io = StringIO.new
    Exporter::NtYaml.new(@commit).export(io, @target_locale)
    # normalize trailing spaces
    str = io.string.split("\n").map(&:rstrip).join("\n")
    str.should eql(<<-YAML.chomp)
---
a message (somewhere):
  string: a message
  comment: somewhere
  translations:
  - locale: es
    string: un mensaje
another message (another place):
  string: another message
  comment: another place
  translations:
  - locale: es
    string: un otro mensaje
    YAML
  end

  describe ".valid?" do
    it "should return true for a syntactically valid YAML hash" do
      expect(Exporter::NtYaml.valid?(<<-YAML)).to be_true
---
ja-JP:
  different: Different (ja-JP)
  same: Same (ja)
      YAML
    end

    it "should return false for a different YAML object" do
      expect(Exporter::NtYaml.valid?(<<-YAML)).to be_false
---
- 1
- 2
      YAML
    end

    it "should return false for a syntactically invalid YANL file" do
      expect(Exporter::NtYaml.valid?(<<-YAML)).to be_false
---
foo: foo: foo
      YAML
    end

    it "should return false for an empty file" do
      expect(Exporter::NtYaml.valid?('')).to be_false
    end
  end
end
