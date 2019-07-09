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

require 'rails_helper'
RSpec.describe Fencer::IntlMessageFormat do
  describe ".fence" do
    # test cases cover all sample from this link: https://formatjs.io/guides/message-syntax

    it "should fence a message format token" do
      expect(Fencer::IntlMessageFormat.fence("String with {two} {tokens}.")).
          to eql(':two' => [-1..0], ':tokens' => [-1..0])
    end

    it "should fence a message format token at the beginning of the string" do
      expect(Fencer::IntlMessageFormat.fence("{one} token in this string.")).
        to eql(':one' => [-1..0])
    end

    it "should fence a message number type format"  do
      expect(Fencer::IntlMessageFormat.fence("Almost {pctBlack, number, percent} of them are black.")).
        to eql(':pctBlack|number|percent' => [-1..0])
    end

    it "should fence a message date type format" do
      expect(Fencer::IntlMessageFormat.fence("Sale begins {start, date, medium}")).
        to eql(':start|date|medium' => [-1..0])
    end

    it "should fence a message time type format" do
      expect(Fencer::IntlMessageFormat.fence("Coupon expires at {expires, time, short}")).
        to eql(':expires|time|short' => [-1..0])
    end

    it "should fence a message select type format" do
      expect(Fencer::IntlMessageFormat.fence("{fruit, select, apple {Apple} banana {Banana} other {Unknown}}")).
        to eql(':fruit|select|apple' => [-1..0], ':fruit|select|banana' => [-1..0], ':fruit|select|other' => [-1..0])
    end

    it "should fence a message nested select type format" do
      expect(Fencer::IntlMessageFormat.fence("{taxableArea, select, yes {An additional {taxRate, number, percent} tax will be collected.} other {No taxes apply.}}")).
        to eql(':taxableArea|select|yes:taxRate|number|percent' => [-1..0], ':taxableArea|select|other' => [-1..0])
    end

    it "should fence a message plural format" do
      expect(Fencer::IntlMessageFormat.fence("Cart: {itemCount} {itemCount, plural, one {item} other {items}}")).
        to eql(':itemCount' => [-1..0], ':itemCount|plural|0|one' => [-1..0], ':itemCount|plural|0|other' => [-1..0])
    end

    it "should fence a message selectordinal format" do
      expect(Fencer::IntlMessageFormat.fence("It's my cat's {year, selectordinal, one {st} two {nd} few {rd} other {3th}} birthday!")).
        to eql(':year|selectordinal|0|one' => [-1..0], ':year|selectordinal|0|two' => [-1..0], ':year|selectordinal|0|few' => [-1..0], ':year|selectordinal|0|other' => [-1..0])
    end

    it "should not fence a string with escaped braces" do
      expect(Fencer::IntlMessageFormat.fence("String with \\{two\\} \\{tokens\\}.")).
        to eql({})
    end

    it "should return empty set if mal-formatted" do
      expect(Fencer::IntlMessageFormat.fence("Sale begins {start, date, mediu")).
        to eql({})
    end
  end

  describe ".valid?" do
    it "should return true for a string with valid interpolations" do
      expect(Fencer::IntlMessageFormat.valid?("String with {valid} {interpolations}.")).to be_truthy
      expect(Fencer::IntlMessageFormat.valid?("{String} that starts with an interpolation.")).to be_truthy
      expect(Fencer::IntlMessageFormat.valid?("String with an escaped brace \\{.")).to be_truthy
      expect(Fencer::IntlMessageFormat.valid?("String with no interpolations.")).to be_truthy
    end

    it "should return false for a string with invalid interpolations" do
      expect(Fencer::IntlMessageFormat.valid?("String with {invalid interpolations.")).to be_falsey
      expect(Fencer::IntlMessageFormat.valid?("String with {{invalid}} interpolations.")).to be_falsey
      expect(Fencer::IntlMessageFormat.valid?("String with {invalid {interpolations}}.")).to be_falsey
    end
  end
end
