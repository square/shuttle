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

# More specs for TranslationUpdateMediator are in translations_controller_specs#update as integration specs.

require 'spec_helper'

describe TranslationUpdateMediator do
  describe "#multi_updateable_translations_to_locale_associations_hash" do
    it "returns a hash of translations that can be updated with the same copy as the primary translation will be
          updated with, and the LocaleAssociations that connect these translations with the primary translation" do
      la1 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA')
      la2 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-FR')
      la3 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-XX')
      la4 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-YY')
      la5 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr-CA', target_rfc5646_locale: 'fr')

      project = FactoryGirl.create(:project, targeted_rfc5646_locales: { 'fr' => true, 'fr-CA' => true, 'fr-FR' => false, 'fr-XX' => true })
      key = FactoryGirl.create(:key, project: project)
      translation1 = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr')
      translation2 = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr-CA')
      translation3 = FactoryGirl.create(:translation, key: key, rfc5646_locale: 'fr-FR')
      expect(TranslationUpdateMediator.multi_updateable_translations_to_locale_associations_hash(translation1)).to eql(translation2 => la1, translation3 => la2)
    end

    it "doesn't consider base translation as a multi updateable translation" do
      la1 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'en-XX', target_rfc5646_locale: 'en')
      la2 = FactoryGirl.create(:locale_association, source_rfc5646_locale: 'en-XX', target_rfc5646_locale: 'en-YY')

      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'en-XX' => true, 'en-YY' => true })
      key = FactoryGirl.create(:key, project: project)
      translation1 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en-XX')
      translation2 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      translation3 = FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en-YY')
      expect(TranslationUpdateMediator.multi_updateable_translations_to_locale_associations_hash(translation1)).to eql(translation3 => la2)
    end
  end
end
