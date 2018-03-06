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
    it "should fence a message format token" do
      expect(Fencer::IntlMessageFormat.fence("String with {two} {tokens}.")).
          to eql('{two}' => [12..16], '{tokens}' => [18..25])
    end

    it "should fence a message format token at the beginning of the string" do
      expect(Fencer::IntlMessageFormat.fence("{one} token in this string.")).
        to eql('{one}' => [0..4])
    end

    it "should not fence a string with escaped braces" do
      expect(Fencer::IntlMessageFormat.fence("String with \\{two\\} \\{tokens\\}.")).
          to eql({})
    end
  end

  describe ".valid?" do
    it "should return true for a string with valid interpolations" do
      expect(Fencer::IntlMessageFormat.valid?("String with {valid} {interpolations}.")).to be_truthy
      expect(Fencer::IntlMessageFormat.valid?("{String} that starts with an interpolation.")).to be_truthy
      expect(Fencer::IntlMessageFormat.valid?("String with an escaped brace '\\{'.")).to be_truthy
      expect(Fencer::IntlMessageFormat.valid?("String with no interpolations.")).to be_truthy
    end

    it "should return false for a string with invalid interpolations" do
      expect(Fencer::IntlMessageFormat.valid?("String with {invalid interpolations.")).to be_falsey
      expect(Fencer::IntlMessageFormat.valid?("String with {{invalid}} interpolations.")).to be_falsey
      expect(Fencer::IntlMessageFormat.valid?("String with {invalid {interpolations}}.")).to be_falsey
    end
  end
end
