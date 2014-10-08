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

describe ProjectTranslationAdderFinisher do
  describe "#on_success" do
    it "runs ProjectTranslationAdderFinisher; sets translation_adder_batch_id to nil" do
      @project = FactoryGirl.create(:project, translation_adder_batch_id: "11111111")
      expect(BatchKeyAndCommitRecalculator).to receive(:perform_once).with(@project.id)
      ProjectTranslationAdderFinisher.new.on_success(nil, { 'project_id' => @project.id })
      expect(@project.reload.translation_adder_batch_id).to be_nil
    end
  end
end
