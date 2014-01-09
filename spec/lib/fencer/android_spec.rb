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

describe Fencer::Android do
  describe ".fence" do
    it "should fence a string with handlebars" do
      expect(Fencer::Android.fence("String with {two} {tokens}.")).
          to eql('{two}' => [12..16], '{tokens}' => [18..25])
    end

    it "should fence a string with double handlebars" do
      expect(Fencer::Android.fence("String with {{two}} {{tokens}}.")).
          to eql('{{two}}' => [12..18], '{{tokens}}' => [20..29])
    end
  end

  describe ".valid?" do
    it "should return true for a string that only contains a-z between { }" do
      expect(Fencer::Android.valid?("String with {two} {tokens}.")).to be_true
    end

    it "should return false for a string that only contains any other character between { }" do
      expect(Fencer::Android.valid?("String with {{two}} {tokens}.")).to be_false
    end
  end
end
