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

describe KeyAncestorsRecalculator do
  describe "#perform" do
    context "KeyGroup" do
      it "recalculates the readiness of the related KeyGroup" do
        project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
        key_group = FactoryGirl.create(:key_group, project: project, ready: false, source_copy: "hi")
        expect(key_group.reload.keys.length).to eql(1)
        key = key_group.keys.first
        expect(key).to_not be_ready
        expect(key_group).to_not be_ready
        expect(key.key_group).to eql(key_group)

        expect(KeyAncestorsRecalculator).to receive(:perform_once).once.and_call_original
        key.translations.in_locale(Locale.from_rfc5646('fr')).first.update! copy: "hi", approved: true
        key.recalculate_ready!

        expect(key.reload).to be_ready
        expect(key_group.reload).to be_ready
      end
    end
  end
end
