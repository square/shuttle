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

describe Fencer::MessageFormat do
  describe ".fence" do
    it "should fence all the strings in the MessageFormat documentation" do
      expect(Fencer::MessageFormat.fence("'{0}'")).
          to eql({})
      expect(Fencer::MessageFormat.fence("ab {0} de")).
          to eql('{0}' => [3..5])
      expect(Fencer::MessageFormat.fence("ab '}' de")).
          to eql({})
      expect(Fencer::MessageFormat.fence("At {1,time} on {1,date}, there was {2} on planet {0,number,integer}.")).
          to eql('{1,time}' => [3..10], '{1,date}' => [15..22], '{2}' => [35..37], '{0,number,integer}' => [49..66])
      expect(Fencer::MessageFormat.fence("The disk \"{1}\" contains {0} file(s).")).
          to eql('{1}' => [10..12], '{0}' => [24..26])
      expect(Fencer::MessageFormat.fence("There {0,choice,0#are no files|1#is one file|1<are {0,number,integer} files}.")).
          to eql('{0,choice,0#are no files|1#is one file|1<are {0,number,integer} files}' => [6..75])
      expect(Fencer::MessageFormat.fence("{0,number,#.##}, {0,number,#.#}")).
          to eql('{0,number,#.##}' => [0..14], '{0,number,#.#}' => [17..30])
    end
  end

  describe ".valid?" do
    it "should return true for a string with valid interpolations" do
      expect(Fencer::MessageFormat.valid?("String with {0} valid {1,number} tokens.")).to be_true
    end

    it "should return false for a string with invalid interpolations" do
      expect(Fencer::MessageFormat.valid?("String with {foo}.")).to be_false
      expect(Fencer::MessageFormat.valid?("String with {0,foo}.")).to be_false
      expect(Fencer::MessageFormat.valid?("String with {0.")).to be_false
    end
  end
end
