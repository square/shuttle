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

describe KeyGroup do
  context "[import!]" do
    it "triggers an import after creation" do
      key_group = FactoryGirl.build(:key_group)
      expect(key_group).to receive(:import!).once
      key_group.save!
    end

    it "triggers an import if source_copy changes" do
      key_group = FactoryGirl.create(:key_group, source_copy: "hello")
      expect(key_group.reload).to receive(:import!).once
      key_group.update!(source_copy: "hi")
    end

    it "triggers an import if targeted_rfc5646_locales changes" do
      key_group = FactoryGirl.create(:key_group, targeted_rfc5646_locales: {'en'=>true})
      expect(key_group.reload).to receive(:import!).once
      key_group.update!(targeted_rfc5646_locales: {'es'=>true})
    end

    it "doesn't trigger an import if other fields such as description or email change" do
      key_group = FactoryGirl.create(:key_group, description: "old description", email: "old@example.com")
      expect(key_group.reload).to_not receive(:import!)
      key_group.update!(description: "new description", email: "new@example.com")
    end
  end
end
