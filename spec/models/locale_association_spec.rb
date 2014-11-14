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

describe LocaleAssociation do
  context "[CRUD]" do
    it "requires source_rfc5646_locale, target_rfc5646_locale, checked, uncheck_disabled fields to be present" do
      association = LocaleAssociation.create(source_rfc5646_locale: nil, target_rfc5646_locale: nil, checked: nil, uncheck_disabled: nil)
      expect(association.errors.full_messages).to eql(["Checked not acceptable", "Uncheck disabled not acceptable", "Source rfc5646 locale can’t be blank", "Target rfc5646 locale can’t be blank", "Target rfc5646 locale cannot equal to source rfc5646 locale"])
    end

    it "doesn't allow target and source locales to be equal" do
      association = FactoryGirl.build(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr')
      association.save
      expect(association.errors.full_messages).to eql(["Target rfc5646 locale cannot equal to source rfc5646 locale"])
    end

    it "doesn't allow setting uncheck_disabled if checked is not set" do
      association = FactoryGirl.build(:locale_association, checked: false, uncheck_disabled: true)
      association.save
      expect(association.errors.full_messages).to eql(["Uncheck disabled cannot disable unchecking if it's not checked by default"])
    end

    it "doesn't allow duplicate source->target pairs" do
      FactoryGirl.create(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA')
      la = FactoryGirl.build(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'fr-CA')
      la.save
      expect(la.errors.full_messages).to eql(["Target rfc5646 locale already taken"])
    end

    it "doesn't allow an association between locales from different families (fr -> es-US)" do
      association = FactoryGirl.build(:locale_association, source_rfc5646_locale: 'fr', target_rfc5646_locale: 'es-US')
      association.save
      expect(association.errors.full_messages).to eql(["Target rfc5646 locale iso639 doesn't match source's"])
    end
  end
end
