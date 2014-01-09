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

describe Fencer::Erb do
  describe ".fence" do
    it "should fence out ERb escapes" do
      expect(Fencer::Erb.fence('An <%= erb %> escape <%another%>.')).
          to eql('<%= erb %>' => [3..12], '<%another%>' => [21..31])
    end

    it "should properly fence ERb escapes with things that look like ERB escapes in them" do
      pending "Hey, did you know regular ERb doesn't support this either??"
      expect(Fencer::Erb.fence('A string <%= "with %> an" %> erb escape')).
          to eql('<%= "with %> an" %>' => [9..27])
    end
  end

  describe ".valid?" do
    it "should return true for a string with balanced interpolation delimiters" do
      expect(Fencer::Erb.valid?("String with <%= two %> <% tokens -%>.")).to be_true
    end

    it "should return false for a string with unbalanced interpolation delimiters" do
      expect(Fencer::Erb.valid?("String with <%= two % > <% tokens -%>.")).to be_false
    end
  end
end
