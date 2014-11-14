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

describe TranslationDecoration do
  before :all do
    class TranslationDecorationTester
      include TranslationDecoration
    end
  end

  before :each do
    @locale_association = LocaleAssociation.create(source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA', checked: true, uncheckable: true)
    @project = FactoryGirl.create(:project, disable_locale_association_checkbox_settings: false)
    key = FactoryGirl.create(:key, project: @project)
    @translation = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr-CA')
  end

  describe "#multi_updateable_translation_checked?" do
    it "returns true if locale association's `checked` field is true and project settings don't disable it" do
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_checked?, @translation, @locale_association)).to be_true
    end

    it "returns false if locale association's `checked` field is false but project settings don't disable it" do
      @locale_association.update! checked: false
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_checked?, @translation, @locale_association)).to be_false
    end

    it "returns false if locale association's `checked` field is true but project settings disable it" do
      @project.update! disable_locale_association_checkbox_settings: true
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_checked?, @translation, @locale_association)).to be_false
    end
  end

  describe "#multi_updateable_translation_uncheckable?" do
    it "returns true if locale association is 'checked' and 'uncheckable', and project settings don't disable it" do
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_uncheckable?, @translation, @locale_association)).to be_true
    end

    it "returns false if locale association is not 'checked' even though it's 'uncheckable' and project settings don't disable it" do
      @locale_association.update! checked: false
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_uncheckable?, @translation, @locale_association)).to be_false
    end

    it "returns false if locale association is not 'uncheckable' even though it's 'checked' and project settings don't disable it" do
      @locale_association.update! uncheckable: false
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_uncheckable?, @translation, @locale_association)).to be_false
    end

    it "returns false if project settings disable it even if locale association is 'checked' and 'uncheckable'" do
      @project.update! disable_locale_association_checkbox_settings: true
      expect(TranslationDecorationTester.new.send(:multi_updateable_translation_uncheckable?, @translation, @locale_association)).to be_false
    end
  end
end
