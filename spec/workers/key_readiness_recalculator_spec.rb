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

describe KeyReadinessRecalculator do
  describe "#perform" do
    it "recalculates the readiness of all the related Commits" do
        project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
        commit1 = FactoryGirl.create(:commit, project: project, ready: false)
        commit2 = FactoryGirl.create(:commit, project: project, ready: false)
        key = FactoryGirl.create(:key, project: project, ready: false)
        key.commits << commit1
        key.commits << commit2

        expect(key).to_not be_ready
        expect(commit1).to_not be_ready
        expect(commit2).to_not be_ready
        expect(key.commits.count).to eql(2)

        expect(KeyReadinessRecalculator).to receive(:perform_once).once.and_call_original

        key.recalculate_ready!

        expect(key.reload).to be_ready
        expect(commit1.reload).to be_ready
        expect(commit2.reload).to be_ready
    end
  end
end
