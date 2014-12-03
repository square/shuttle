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

describe KeyTranslationAdderAndRemover do
  describe "#perform" do
    it "adds missing translations and removes excluded untranslated translations" do
      project = FactoryGirl.create(:project, :light, targeted_rfc5646_locales: {'es'=>true, 'fr'=>true}, base_rfc5646_locale: 'en')
      key = FactoryGirl.create(:key, key: "firstkey",  project: project)
      FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en', source_copy: 'fake', copy: 'fake', approved: true)
      FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'es', source_copy: 'fake', copy: 'fake', approved: true)
      FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', source_copy: 'fake', copy: nil, approved: nil)

      expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once).once # because we will call KeyTranslationAdderAndRemover manually
      project.update! key_locale_exclusions: { 'fr' => ["*firstkey*"] }, targeted_rfc5646_locales: {'es'=>true, 'fr'=>true, 'ja'=>true}
      KeyTranslationAdderAndRemover.new.perform(key.id)

      expect(key.reload.translations.map(&:rfc5646_locale).sort).to eql(%w(en es ja))
      expect(key.translations.order(:created_at).last.rfc5646_locale).to eql('ja')
    end

  end
end
