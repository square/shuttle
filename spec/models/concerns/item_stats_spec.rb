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

describe ItemStats do
  describe "#fetch_stat" do
    before :each do
      @commit = FactoryGirl.build(:commit)
      @commit.stub(:stats).and_return( {
                                          approved: { translations_count: 1, words_count: 2 },
                                          pending: { translations_count: 1, words_count: 1 }
                                       })
    end

    it "returns the default value if state is not in stats hash" do
      expect(@commit.send :fetch_stat, [], :new, :translations_count, :doesnt_exist).to eql(:doesnt_exist)
    end

    it "returns the default value if field is not in stats hash" do
      expect(@commit.send :fetch_stat, [], :approved, :fake_count).to eql(0)
    end

    it "returns the correct value if state and field exist in stats hash" do
      expect(@commit.send :fetch_stat, [], :approved, :words_count).to eql(2)
    end
  end
end
