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
  describe "#update_translation_memory" do
    before :each do
      @translation = FactoryGirl.create(:translation, source_rfc5646_locale: 'en', rfc5646_locale: 'de', source_copy: "test", copy: nil)
      expect(TranslationUnit.source_copy_matches("test").where(source_rfc5646_locale: "en", rfc5646_locale: "de").exists?).to be_false
    end

    it "create a new TranslationUnit when a translator translates and approves a Translation" do
      @translation.update! copy: "test", approved: true, modifier: FactoryGirl.create(:user)
      expect(TranslationUnit.source_copy_matches("test").where(source_rfc5646_locale: "en", rfc5646_locale: "de").exists?).to be_true
    end

    it "doesn't create a new TranslationUnit if a Translation is translated and approved automatically without a user (ex: mass copied from another locale)" do
      @translation.update! copy: "test", approved: true
      expect(TranslationUnit.source_copy_matches("test").where(source_rfc5646_locale: "en", rfc5646_locale: "de").exists?).to be_false
    end
  end
end
