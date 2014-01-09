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

describe Fencer do
  describe ".multifence" do
    it "should remove invalid fences overlapped by valid fences" do
      expect(Fencer.multifence(%w(Erb Html), "<%= 'foo <b' %> b<%=a%>r <%= 'bar >' %>.")).to eql(
                                                                                             "<%= 'foo <b' %>" => [0..14],
                                                                                             "<%=a%>"          => [17..22],
                                                                                             "<%= 'bar >' %>"  => [25..38]
                                                                                         )
    end

    it "should remove invalid fences overlapped by multiple valid fences" do
      expect(Fencer.multifence(%w(Erb Html), "<%= 'foo <b' %> <b bar<b> <%= 'bar >' %>.")).to eql(
                                                                                              "<%= 'foo <b' %>" => [0..14],
                                                                                              "<%= 'bar >' %>"  => [26..39],
                                                                                              "<b>"             => [22..24]
                                                                                          )
    end

    it "should not fence ranges caught by earlier fences in subsequent fencings" do
      expect(Fencer.multifence(%w(Erb Html), "<%= 'b<b>old' %>.")).to eql(
                                                                      "<%= 'b<b>old' %>" => [0..15]
                                                                  )
    end
  end
end
