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

shared_examples_for "CommonLocaleLogic" do
  let(:model_name) { described_class.to_s.underscore.to_sym } # the class that includes the concern

  context "[validations]" do
    context "[prevent_base_locale_from_changing]" do
      let(:object) { FactoryGirl.create(model_name, base_rfc5646_locale: 'en') }

      it "prevents base locale from changing on update" do
        object.update(base_rfc5646_locale: 'es')
        expect(object.errors.messages[:base_rfc5646_locale]).to eql(["cannot be changed"])
      end

      it "doesn't prevent update if base locale is not changed" do
        object.update!(base_rfc5646_locale: 'en')
        expect(object.errors[:base_rfc5646_locale]).to be_empty
      end
    end

    context "[require_valid_targeted_rfc5646_locales_hash]" do
      it "adds an error if there are non-boolean values" do
        object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => 1}).tap(&:valid?)
        expect(object.errors[:targeted_rfc5646_locales]).to include("invalid")
      end

      it "doesn't add an error if nil" do
        object = FactoryGirl.build(model_name, targeted_rfc5646_locales: nil).tap(&:valid?)
        expect(object.errors[:targeted_rfc5646_locales]).to_not include("invalid")
      end

      it "doesn't add an error if it's a valid hash" do
        object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => true}).tap(&:valid?)
        expect(object.errors[:targeted_rfc5646_locales]).to_not include("invalid")
      end
    end

    it "doesn't create a record if base_rfc5646_locale is ill-formatted" do
      record = FactoryGirl.build(model_name, base_rfc5646_locale: 'en-en-en-en-en')
      record.save
      expect(record).to_not be_persisted
      expect(record.errors.full_messages).to eql(["source locale invalid"])
    end

    it "doesn't create a record if targeted_rfc5646_locales is ill-formatted" do
      record = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'fr' => 'true'})
      record.save
      expect(record).to_not be_persisted
      expect(record.errors.full_messages).to eql(["targeted localizations invalid"])
    end
  end

  describe "#base_locale" do
    it "returns base locale as a Locale object" do
      object = FactoryGirl.build(model_name, base_rfc5646_locale: 'en')
      expect(object.base_locale).to eql(Locale.from_rfc5646('en'))
    end
  end

  describe "#locale_requirements" do
    it "returns locale requirements as a hash of Locale objects to booleans" do
      object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => true, 'fr' => false })
      expect(object.locale_requirements).to eql({ Locale.from_rfc5646('es') => true, Locale.from_rfc5646('fr') => false })
    end

    it "writes locale requirements as a hash of Locale objects to booleans" do
      object = FactoryGirl.build(model_name, targeted_rfc5646_locales: nil)
      object.locale_requirements = { Locale.from_rfc5646('es') => true }
      expect(object.targeted_rfc5646_locales).to eql({'es' => true})
    end
  end

  describe "#targeted_locales" do
    it "returns targeted locales as an array of Locale objects" do
      object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => true, 'fr' => false })
      expect(object.targeted_locales).to eql([Locale.from_rfc5646('es'), Locale.from_rfc5646('fr') ])
    end
  end

  describe "#required_locales" do
    it "returns required locales as an array of Locale objects" do
      object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => true, 'fr' => false })
      expect(object.required_locales).to eql([Locale.from_rfc5646('es')])
    end
  end

  describe "#required_rfc5646_locales" do
    it "returns required locales as an array of Strings" do
      object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => true, 'fr' => false })
      expect(object.required_rfc5646_locales).to eql(['es'])
    end
  end

  describe "#other_rfc5646_locales" do
    it "returns other (optional) locales as an array of Strings" do
      object = FactoryGirl.build(model_name, targeted_rfc5646_locales: {'es' => true, 'fr' => false })
      expect(object.other_rfc5646_locales).to eql(['fr'])
    end
  end
end
