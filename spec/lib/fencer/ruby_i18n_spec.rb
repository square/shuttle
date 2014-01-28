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

describe Fencer::RubyI18n do
  describe ".fence" do
    it "should fence a string with I18n escapes" do
      expect(Fencer::RubyI18n.fence("String with %{two} %{tokens}.")).
          to eql('%{two}' => [12..17], '%{tokens}' => [19..27])
    end
  end
end
