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

describe ImportFinisher do
  describe "#on_success" do
    before :each do
      @project = FactoryGirl.create(:project, :light)
      @commit = FactoryGirl.create(:commit, project: @project, loading: true)
      @key = FactoryGirl.create(:key, project: @project)
      @commit.keys << @key
      @translation = FactoryGirl.create(:translation, key: @key, copy: "test")
    end

    it "sets loading to false and sets ready to true if all translations are finished" do
      @translation.update! source_copy: "test", approved: true, skip_readiness_hooks: true
      expect(@commit.reload).to be_loading
      expect(@commit).to_not be_ready
      ImportFinisher.new.on_success true, 'commit_id' => @commit.id
      expect(@commit.reload).to_not be_loading
      expect(@commit).to be_ready
    end

    it "sets loading to false and sets ready to false if some translations are not translated" do
      expect(@commit.reload).to be_loading
      expect(@commit).to_not be_ready
      ImportFinisher.new.on_success true, 'commit_id' => @commit.id
      expect(@commit.reload).to_not be_loading
      expect(@commit).to_not be_ready
    end

    it "recalculates keys' readiness, sets to false if not all translations are approved" do
      @key.update! ready: true
      ImportFinisher.new.on_success true, 'commit_id' => @commit.id
      expect(@key.reload).to_not be_ready
    end

    it "recalculates keys' readiness, sets to true if all translations are approved" do
      @translation.update! source_copy: "test", approved: true, skip_readiness_hooks: true
      @key.update! ready: false
      ImportFinisher.new.on_success true, 'commit_id' => @commit.id
      expect(@key.reload).to be_ready
    end
  end
end
