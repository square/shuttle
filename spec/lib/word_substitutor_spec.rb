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

describe WordSubstitutor do
  context "[pathfinding]" do
    before :each do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should perform substitutions for a one-edge path" do
      expect(@sub.substitutions('color').string).to eql('colour')
    end

    it "should perform substitutions for a multi-edge path" do
      sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-scotland'))
      expect(sub.substitutions('baby').string).to eql('bairn')
    end

    it "should shift the ranges for multi-edge paths" do
      sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-scotland'))
      result = sub.substitutions('baby elevator')
      expect(result.string).to eql('bairn elevator')
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(6..13) # shifted over 1 because of the change from baby to bairn
    end

    it "should raise NoDictionaryError if no route exists" do
      expect { WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('fr')) }.
          to raise_error(WordSubstitutor::NoDictionaryError)
    end
  end

  context "[:auto mode]" do
    before :each do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should automatically apply the substitution to an exact match" do
      expect(@sub.substitutions("The color of love.").string).to eql("The colour of love.")
      expect(@sub.substitutions("Color me surprised.").string).to eql("Colour me surprised.")
      expect(@sub.substitutions("Color's a relationalist notion.").string).to eql("Colour's a relationalist notion.")
    end

    it "should automatically apply the substitution to a stem match" do
      expect(@sub.substitutions("The colors of love.").string).to eql("The colours of love.")
      expect(@sub.substitutions("Colored surprised.").string).to eql("Coloured surprised.")
      expect(@sub.substitutions("The coloring's reaction").string).to eql("The colouring's reaction")
    end

    it "should add a suggestion if the capitalization is funky" do
      result = @sub.substitutions("CoLoR pWn3D")
      expect(result.string).to eql("CoLoR pWn3D")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(0..4)
      # expect(result.suggestions.first.replacement).to eql('colour')
      # expect(result.suggestions.first.note).to eql("Couldn’t figure out the capitalization for this automatic substitution")
    end

    it "should favor larger matches" do
      result = @sub.substitutions("All I got was a busy signal.")
      expect(result.string).to eql("All I got was a engaged tone.")
      # expect(result.suggestions).to be_empty # no suggestion to change "signal" to "indicate"
    end

    it "should work for stemmed matches on phrases" do
      result = @sub.substitutions("All we got were busy signals.")
      expect(result.string).to eql("All we got were engaged tones.")
      # expect(result.suggestions).to be_empty # no suggestion to change "signals" to "indicates"
    end

    it "should automatically give priority to an exact match" do
      result = @sub.substitutions("Signaling is using your signal light to signal your lane change.")
      expect(result.string).to eql("Signalling is using your indicator to signal your lane change.")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(38..43)
      # expect(result.suggestions.first.replacement).to eql('indicate')
      # expect(result.suggestions.first.note).to eql("using one’s turn signal when driving")
    end

    it "should append a note if the substitution comes with a note" do
      result = @sub.substitutions("Aluminum can")
      expect(result.string).to eql("Aluminium can")
      # expect(result.notes.size).to eql(1)
      # expect(result.notes.first.range).to eql(0..8)
      # expect(result.notes.first.note).to eql("en-US usage is based on the brand Aluminum; en-GB is based on the element")
    end
  end

  context "[:prompt mode]" do
    before :each do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should add a suggestion to an exact match" do
      result = @sub.substitutions("Going to the bathroom")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(13..20)
      # expect(result.suggestions.first.replacement).to eql("toilet")
      # expect(result.suggestions.first.note).to eql("when referring to a WC, not a room with a bath")

      result = @sub.substitutions("Bathroom is that way")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(0..7)
      # expect(result.suggestions.first.replacement).to eql("Toilet")

      result = @sub.substitutions("Bathroom's that way")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(0..7)
      # expect(result.suggestions.first.replacement).to eql("Toilet")
    end

    it "should add a suggestion to a stemmed match" do
      result = @sub.substitutions("So many bathrooms")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(8..16)
      # expect(result.suggestions.first.replacement).to eql("toilets")
      # expect(result.suggestions.first.note).to eql("when referring to a WC, not a room with a bath")

      result = @sub.substitutions("Bathrooms are that way")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(0..8)
      # expect(result.suggestions.first.replacement).to eql("Toilets")

      result = @sub.substitutions("The bathrooms' light fixtures")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(4..12)
      # expect(result.suggestions.first.replacement).to eql("toilets")
    end

    it "should favor larger matches" do
      result = @sub.substitutions("He yelled “CANDY BARS” while licking the divider.")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(11..20)
      # expect(result.suggestions.first.replacement).to eql("CHOCOLATE BARS") # not "SWEET BARS"
    end

    it "should automatically give priority to an exact match" do
      pending "No words in dictionary to test this with"
      #result = @sub.substitutions("All the boxes were checked.")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(19..25)
      result.suggestions.first.replacement.should eql("ticked, checkquered") # not "cheque, ticked"
    end
  end

  context "[:stemmed mode]" do
    before :each do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should apply the substitution to the inflection" do
      expect(@sub.substitutions("They dueled at work").string).to eql("They duelled at work")
      expect(@sub.substitutions("Dueling at work is forbidden").string).to eql("Duelling at work is forbidden")
      expect(@sub.substitutions("NO DUELING").string).to eql("NO DUELLING")
    end

    it "should add a suggestion if the capitalization is funky" do
      result = @sub.substitutions("y u nOt dUeling mE")
      expect(result.string).to eql("y u nOt dUeling mE")
      # expect(result.suggestions.size).to eql(1)
      # expect(result.suggestions.first.range).to eql(8..14)
      # expect(result.suggestions.first.replacement).to eql('duelling')
      # expect(result.suggestions.first.note).to eql("Couldn’t figure out the capitalization for this stemmed substitution")
    end

    it "should favor larger matches"
    it "should add a suggestion if it could not determine how to apply the inflection" #TODO
  end

  it "should handle some hard cases" do
    sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))

    expect(sub.substitutions('digitized').string).to eql('digitised')
    expect(sub.substitutions('parentheses').string).to eql('brackets')
  end

  describe WordSubstitutor::Result do
    it "should JSON-serialize" do
      suggestions = [
          WordSubstitutor::Suggestion.new(1..10, 'foo', 'some suggestion'),
          WordSubstitutor::Suggestion.new(15..20, 'bar', 'other suggestion')
      ]
      notes       = [
          WordSubstitutor::Note.new(1..9, 'some note'),
          WordSubstitutor::Note.new(15..21, 'other note')
      ]
      expect(WordSubstitutor::Result.new('foobar', notes, suggestions).to_json).
          to eql(
                     {
                         'string'      => 'foobar',
                         'notes'       => [
                             {'range' => [1, 9], 'note' => 'some note'},
                             {'range' => [15, 21], 'note' => 'other note'}
                         ],
                         'suggestions' => [
                             {'range' => [1, 10], 'replacement' => 'foo', 'note' => 'some suggestion'},
                             {'range' => [15, 20], 'replacement' => 'bar', 'note' => 'other suggestion'}
                         ]
                     }.to_json
                 )
    end
  end
end
