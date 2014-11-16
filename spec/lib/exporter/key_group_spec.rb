# encoding: utf-8

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

describe Exporter::KeyGroup do
  describe "#export" do
    before :all do
      @fr_locale = Locale.from_rfc5646('fr')
      @es_locale = Locale.from_rfc5646('es')
      @ja_locale = Locale.from_rfc5646('ja')
    end

    before :each do
      @project = FactoryGirl.create(:project, repository_url: nil)
      @key_group = FactoryGirl.create(:key_group, project: @project, ready: false, source_copy: "<p>hello</p><p>world</p>", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
      expect(@key_group.reload.keys.count).to eql(2)

      @fr_translations = @key_group.active_translations.in_locale(@fr_locale).order("keys.index_in_key_group")
      @es_translations = @key_group.active_translations.in_locale(@es_locale).order("keys.index_in_key_group")
      @ja_translations = @key_group.active_translations.in_locale(@ja_locale).order("keys.index_in_key_group")

      @fr_translations[0].update! copy: "<p>bonjour</p>", approved: true
      @fr_translations[1].update! copy: "<p>monde</p>", approved: true
      @es_translations[0].update! copy: "<p>hola</p>", approved: true
      @es_translations[1].update! copy: "<p>mundo</p>", approved: true

      @key_group.keys.reload.each(&:recalculate_ready!)
      expect(@key_group.reload).to be_ready
    end

    it "raises InputError if no locales are provided" do
      expect { Exporter::KeyGroup.new(@key_group).send(:export, []) }.to raise_error(Exporter::KeyGroup::InputError, "No Locale(s) Inputted")
    end

    it "raises InputError if an invalid locale in rfc5646 representation is provided" do
      expect { Exporter::KeyGroup.new(@key_group).send(:export, "fr, invalid-locale") }.to raise_error(Exporter::KeyGroup::InputError, "Locale 'invalid-locale' could not be found.")
    end

    it "raises InputError if one of the requested locales is not a required locale" do
      expect { Exporter::KeyGroup.new(@key_group).send(:export, [@fr_locale, @ja_locale]) }.to raise_error(Exporter::KeyGroup::InputError, "Inputted locale 'ja' is not one of the required locales for this key group.")
    end

    it "raises NotReadyError if KeyGroup is not ready" do
      @es_translations[0].update! approved: false
      @es_translations[0].key.reload.recalculate_ready!
      expect(@key_group.reload).to_not be_ready
      expect { Exporter::KeyGroup.new(@key_group).send(:export) }.to raise_error(Exporter::KeyGroup::NotReadyError)
    end

    it "returns the correct translations when string locales are provided" do
      expect(Exporter::KeyGroup.new(@key_group).send(:export, "fr, es")).to eql( { 'fr' => "<p>bonjour</p><p>monde</p>", 'es' => "<p>hola</p><p>mundo</p>" } )
    end

    it "returns the correct translations when only some of the required locales are requested" do
      expect(Exporter::KeyGroup.new(@key_group).send(:export, [@fr_locale])).to eql( { 'fr' => "<p>bonjour</p><p>monde</p>" } )
    end

    it "returns the correct translations for all required locales when no locales are specified" do
      expect(Exporter::KeyGroup.new(@key_group).send(:export)).to eql( { 'fr' => "<p>bonjour</p><p>monde</p>", 'es' => "<p>hola</p><p>mundo</p>" } )
    end
  end

  describe "#export_locale" do
    before :all do
      @fr_locale = Locale.from_rfc5646('fr')
    end

    before :each do
      @project = FactoryGirl.create(:project, repository_url: nil)
      @key_group = FactoryGirl.create(:key_group, project: @project, source_copy: "<p>hello</p><p>world</p>", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true })
      expect(@key_group.reload.keys.count).to eql(2)
      @fr_translations = @key_group.translations.in_locale(@fr_locale).order("keys.index_in_key_group")
    end

    it "returns the full translation of KeyGroup in the given locale" do
      @fr_translations[0].update! copy: "<p>bonjour</p>"
      @fr_translations[1].update! copy: "<p>monde</p>"
      expect(Exporter::KeyGroup.new(@key_group).send(:export_locale, @fr_locale)).to eql("<p>bonjour</p><p>monde</p>")
    end

    it "raises MissingTranslation error if a translation is missing from this locale" do
      @fr_translations[0].update! copy: "<p>bonjour</p>"
      @fr_translations[1].delete

      expect { Exporter::KeyGroup.new(@key_group).send(:export_locale, @fr_locale) }.to raise_error(Exporter::KeyGroup::MissingTranslation)
    end
  end
end
