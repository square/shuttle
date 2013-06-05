# encoding: utf-8

# Copyright 2013 Square Inc.
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

# encoding: utf-8

require 'spec_helper'

describe WordSubstitutor do
  context "[pathfinding]" do
    before :all do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should perform substitutions for a one-edge path" do
      @sub.substitutions('color').string.should eql('colour')
    end

    it "should perform substitutions for a multi-edge path" do
      sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-scotland'))
      sub.substitutions('baby').string.should eql('bairn')
    end

    it "should shift the ranges for multi-edge paths" do
      sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-scotland'))
      result = sub.substitutions('baby elevator')
      result.string.should eql('bairn elevator')
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(6..13) # shifted over 1 because of the change from baby to bairn
    end

    it "should raise NoDictionaryError if no route exists" do
      -> { WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('fr')) }.
          should raise_error(WordSubstitutor::NoDictionaryError)
    end
  end

  context "[:auto mode]" do
    before :all do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should automatically apply the substitution to an exact match" do
      @sub.substitutions("The color of love.").string.should eql("The colour of love.")
      @sub.substitutions("Color me surprised.").string.should eql("Colour me surprised.")
      @sub.substitutions("Color's a relationalist notion.").string.should eql("Colour's a relationalist notion.")
    end

    it "should automatically apply the substitution to a stem match" do
      @sub.substitutions("The colors of love.").string.should eql("The colours of love.")
      @sub.substitutions("Colored surprised.").string.should eql("Coloured surprised.")
      @sub.substitutions("The coloring's reaction").string.should eql("The colouring's reaction")
    end

    it "should add a suggestion if the capitalization is funky" do
      result = @sub.substitutions("CoLoR pWn3D")
      result.string.should eql("CoLoR pWn3D")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(0..4)
      result.suggestions.first.replacement.should eql('colour')
      result.suggestions.first.note.should eql("Couldn’t figure out the capitalization for this automatic substitution")
    end

    it "should favor larger matches" do
      result = @sub.substitutions("All I got was a busy signal.")
      result.string.should eql("All I got was a engaged tone.")
      result.suggestions.should be_empty # no suggestion to change "signal" to "indicate"
    end

    it "should work for stemmed matches on phrases" do
      result = @sub.substitutions("All we got were busy signals.")
      result.string.should eql("All we got were engaged tones.")
      result.suggestions.should be_empty # no suggestion to change "signals" to "indicates"
    end

    it "should automatically give priority to an exact match" do
      result = @sub.substitutions("Signaling is using your signal light to signal your lane change.")
      result.string.should eql("Signalling is using your indicator to signal your lane change.")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(38..43)
      result.suggestions.first.replacement.should eql('indicate')
      result.suggestions.first.note.should eql("using one’s turn signal when driving")
    end

    it "should append a note if the substitution comes with a note" do
      result = @sub.substitutions("Aluminum can")
      result.string.should eql("Aluminium can")
      result.notes.size.should eql(1)
      result.notes.first.range.should eql(0..8)
      result.notes.first.note.should eql("en-US usage is based on the brand Aluminum; en-GB is based on the element")
    end
  end

  context "[:prompt mode]" do
    before :all do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should add a suggestion to an exact match" do
      result = @sub.substitutions("Going to the bathroom")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(13..20)
      result.suggestions.first.replacement.should eql("toilet")
      result.suggestions.first.note.should eql("when referring to a WC, not a room with a bath")

      result = @sub.substitutions("Bathroom is that way")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(0..7)
      result.suggestions.first.replacement.should eql("Toilet")

      result = @sub.substitutions("Bathroom's that way")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(0..7)
      result.suggestions.first.replacement.should eql("Toilet")
    end

    it "should add a suggestion to a stemmed match" do
      result = @sub.substitutions("So many bathrooms")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(8..16)
      result.suggestions.first.replacement.should eql("toilets")
      result.suggestions.first.note.should eql("when referring to a WC, not a room with a bath")

      result = @sub.substitutions("Bathrooms are that way")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(0..8)
      result.suggestions.first.replacement.should eql("Toilets")

      result = @sub.substitutions("The bathrooms' light fixtures")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(4..12)
      result.suggestions.first.replacement.should eql("toilets")
    end

    it "should favor larger matches" do
      result = @sub.substitutions("He yelled “CANDY BARS” while licking the divider.")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(11..20)
      result.suggestions.first.replacement.should eql("CHOCOLATE BARS") # not "SWEET BARS"
    end

    it "should automatically give priority to an exact match" do
      pending "No words in dictionary to test this with"
      #result = @sub.substitutions("All the boxes were checked.")
      #result.suggestions.size.should eql(1)
      #result.suggestions.first.range.should eql(19..25)
      #result.suggestions.first.replacement.should eql("ticked, checkquered") # not "cheque, ticked"
    end
  end

  context "[:stemmed mode]" do
    before :all do
      @sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))
    end

    it "should apply the substitution to the inflection" do
      @sub.substitutions("They dueled at work").string.should eql("They duelled at work")
      @sub.substitutions("Dueling at work is forbidden").string.should eql("Duelling at work is forbidden")
      @sub.substitutions("NO DUELING").string.should eql("NO DUELLING")
    end

    it "should add a suggestion if the capitalization is funky" do
      result = @sub.substitutions("y u nOt dUeling mE")
      result.string.should eql("y u nOt dUeling mE")
      result.suggestions.size.should eql(1)
      result.suggestions.first.range.should eql(8..14)
      result.suggestions.first.replacement.should eql('duelling')
      result.suggestions.first.note.should eql("Couldn’t figure out the capitalization for this stemmed substitution")
    end

    it "should favor larger matches"
    it "should add a suggestion if it could not determine how to apply the inflection" #TODO
  end

  it "should handle some hard cases" do
    sub = WordSubstitutor.new(Locale.from_rfc5646('en-US'), Locale.from_rfc5646('en-GB'))

    sub.substitutions('digitized').string.should eql('digitised')
    sub.substitutions('parentheses').string.should eql('brackets')
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
      WordSubstitutor::Result.new('foobar', notes, suggestions).to_json.
          should eql(
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
