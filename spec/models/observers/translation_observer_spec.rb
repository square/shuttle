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

describe TranslationObserver do
  context "[translation changes]" do
    before :each do
      @trans = FactoryGirl.create(:translation)
    end

    it "should log the change and the changer when a user changes the translation" do
      old_copy   = @trans.copy
      new_copy   = "A new translation"
      translator = FactoryGirl.create(:user)
      expect {
        @trans.copy     = new_copy
        @trans.modifier = translator
        @trans.save
      }.to change { TranslationChange.count }.by(1)
      change = TranslationChange.last
      expect(change.diff).to eq({"copy" => [old_copy, new_copy]})
      expect(change.user).to eq(translator)
    end

    it "should log the approval and the approver when a user approves the translation" do
      approver = FactoryGirl.create(:user)
      expect {
        @trans.approved = true
        @trans.modifier = approver
        @trans.save
      }.to change { TranslationChange.count }.by(1)
      change = TranslationChange.last
      expect(change.diff).to eq({"approved" => [nil, true]})
      expect(change.user).to eq(approver)
    end

    it "should not log a change when a field we don't care about changes" do
      expect {
        @trans.updated_at = Time.now
        @trans.save
      }.to_not change { TranslationChange.count }
    end

    it "should not log a user when the computer modifies the Translation" do
      expect {
        @trans.copy = "A new translation"
        @trans.save
      }.to change { TranslationChange.count }.by(1)
      change = TranslationChange.last
      expect(change.user).to eq(nil)
    end
  end
end
