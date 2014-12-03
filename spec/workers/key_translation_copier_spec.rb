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

describe KeyTranslationCopier do
  describe "#perform" do
    before :each do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'fr' => true, 'fr-XX' => true, 'fr-YY' => false, 'es-XX' => false })
      @key = FactoryGirl.create(:key, project: @project, ready: false)
      @fr_translation    = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'fr', copy: 'test', approved: true)
      @fr_xx_translation = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'fr-XX', copy: nil, approved: nil)
    end

    it "copies translation.copy from the given source locale to given target locale" do
      KeyTranslationCopier.new.perform(@key.id, 'fr', 'fr-XX')
      expect(@fr_xx_translation.reload.copy).to eql('test')
    end

    it "sets approved state to true" do
      KeyTranslationCopier.new.perform(@key.id, 'fr', 'fr-XX')
      expect(@fr_xx_translation.reload.approved).to be_true
    end

    it "doesn't copy from not-approved Translation" do
      @fr_translation.update! approved: nil
      KeyTranslationCopier.new.perform(@key.id, 'fr', 'fr-XX')
      expect(@fr_xx_translation.reload.copy).to be_nil
      expect(@fr_xx_translation.approved).to be_nil
    end

    it "doesn't copy to translated Translation" do
      @fr_xx_translation.update! copy: 'helloworld', approved: nil
      KeyTranslationCopier.new.perform(@key.id, 'fr', 'fr-XX')
      expect(@fr_xx_translation.reload.copy).to eql('helloworld')
      expect(@fr_xx_translation.approved).to be_nil
    end

    it "doesn't copy to base Translation" do
      en_translation    = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'en',    copy: nil,          approved: nil)
      en_xx_translation = FactoryGirl.create(:translation, key: @key, source_copy: "fake", source_rfc5646_locale: 'en', rfc5646_locale: 'en-XX', copy: 'helloworld', approved: true)
      KeyTranslationCopier.new.perform(@key.id, 'en-XX', 'en')
      expect(en_translation.reload.copy).to be_nil
      expect(en_translation.approved).to be_nil
    end

    it "doesn't error if from_translation couldn't be found (maybe that key was blacklisted in that source locale)" do
      expect { KeyTranslationCopier.new.perform(@key.id, 'fr-AA', 'fr-XX') }.to_not raise_error
      expect(@fr_xx_translation.reload.copy).to be_nil
      expect(@fr_xx_translation.approved).to be_nil
    end

    it "doesn't error if to_translation couldn't be found (maybe that key was blacklisted in that target locale)" do
      expect { KeyTranslationCopier.new.perform(@key.id, 'fr', 'fr-AA') }.to_not raise_error
    end

    it "ignores from translations in other source locales than the project" do
      FactoryGirl.create(:translation, key: @key, source_rfc5646_locale: 'en-ZZ', rfc5646_locale: 'fr-YY', copy: 'test', approved: true)
      KeyTranslationCopier.new.perform(@key.id, 'fr-YY', 'fr-XX')
      expect(@fr_xx_translation.reload.copy).to be_nil
      expect(@fr_xx_translation.approved).to be_nil
    end

    it "ignores to translations in other source locales than the project" do
      fr_yy_translation = FactoryGirl.create(:translation, key: @key, source_rfc5646_locale: 'en-ZZ', rfc5646_locale: 'fr-YY', copy: nil, approved: nil)
      KeyTranslationCopier.new.perform(@key.id, 'fr', 'fr-YY')
      expect(fr_yy_translation.reload.copy).to be_nil
      expect(fr_yy_translation.approved).to be_nil
    end
  end
end
