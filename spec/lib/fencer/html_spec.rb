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

require 'spec_helper'

describe Fencer::Html do
  describe ".fence" do
    it "should fence out HTML tags" do
      Fencer::Html.fence('String with <token one="two" three-four=five six>two< /token > tokens.').
          should eql('<token one="two" three-four=five six>' => [12..48], '< /token >' => [52..61])
    end

    it "should fence self-closing tags" do
      Fencer::Html.fence('Hello <br/> world < br / >.').
          should eql('<br/>' => [6..10], '< br / >' => [18..25])
    end

    it "should fence out named HTML character entities" do
      Fencer::Html.fence("Tim&rsquo;s test string &lt;hello&rt;.").
          should eql('&rsquo;' => [3..9], '&lt;' => [24..27], '&rt;' => [33..36])
    end

    it "should fence out numeric HTML character entities" do
      Fencer::Html.fence("Tim&#x2019;s test string &#60;hello&#62;.").
          should eql('&#x2019;' => [3..10], '&#60;' => [25..29], '&#62;' => [35..39])
    end

    it "should not fence out things that look like HTML character tags" do
      Fencer::Html.fence("Hello&; Hello & world ; also 5 > 3 and 2 < 5.").
                should eql({})
    end
  end

  describe ".valid?" do
    it "should return true for a string with valid XHTML" do
      Fencer::Html.valid?('Some <b id="bar">valid<br /> XHTML</b>.').should be_true
    end

    it "should return true for a string with valid HTML5" do
      Fencer::Html.valid?("Some <b id=bar>valid<br> HTML</b>.").should be_true
    end

    it "should return false for a string with invalid HTML" do
      Fencer::Html.valid?("An <unknown>tag.").should be_false
      Fencer::Html.valid?("An <b>unclosed tag.").should be_false
      Fencer::Html.valid?("A <b>mismatched tag</i>.").should be_false
      Fencer::Html.valid?("An <<b>/>invalid</b>tag.").should be_false
    end
  end
end
