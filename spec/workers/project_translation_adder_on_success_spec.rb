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

describe ProjectTranslationAdderOnSuccess do
  describe "#perform" do
    it "recalculates ready for all keys of the project and calls CommitStatsRecalculator for each commit of the project" do
      # setup
      @project = FactoryGirl.create(:project)
      @commit1 = FactoryGirl.create(:commit, project: @project)
      @commit2 = FactoryGirl.create(:commit, project: @project)
      @key1 = FactoryGirl.create(:key, project: @project)
      @key2 = FactoryGirl.create(:key, project: @project)
      @commit1.keys = [@key1, @key2]
      @commit2.keys = [@key1, @key2]

      @project.keys.update_all ready: false
      expect(CommitStatsRecalculator).to receive(:perform_once).with(@commit1.id)
      expect(CommitStatsRecalculator).to receive(:perform_once).with(@commit2.id)

      ProjectTranslationAdderOnSuccess.new.perform(@project.id)
      expect(@key1.reload).to be_ready
      expect(@key2.reload).to be_ready
    end
  end
end
