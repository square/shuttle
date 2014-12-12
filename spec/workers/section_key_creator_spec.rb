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

describe SectionKeyCreator do
  describe "#perform" do
    before :each do
      Article.any_instance.stub(:import!) # prevent imports, we want to handle things manually
      @article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'ja' => true, 'es' => false } )
      @section = FactoryGirl.create(:section, article: @article)
    end

    it "creates Key and related Translations in base & targeted locales" do
      SectionKeyCreator.new.perform(@section.id, "<p>test</p>", 3)
      expect(@section.reload.keys.count).to eql(1)

      key = @section.keys.first

      expect(key.key).to eql("3:5aec4fa35b3f3ed05e784fcd81b10863230e44a8bbf3b0cfd963580da045401a")
      expect(key.index_in_section).to eql(3)
      expect(key.project).to eql(@section.project)
      expect(key.source_copy).to eql("<p>test</p>")
      expect(key.ready).to be_false

      expect(key.translations.count).to eql(4) # the correct number of translations are created
      expect(key.translations.map(&:rfc5646_locale).sort).to eql(%w(en fr ja es).sort)

      base_translation = key.translations.where(rfc5646_locale: 'en', source_rfc5646_locale: 'en').first
      expect(base_translation.copy).to eql(base_translation.source_copy)
      expect(base_translation).to be_approved
    end

    it "doesn't create new Key or Translations if a Article is submitted for re-import with the same settings, ie. SectionKeyCreator is run twice with same args" do
      SectionKeyCreator.new.perform(@section.id, "<p>test</p>", 0)
      expect(@section.reload.translations.count).to eql(4)

      last_key_id = Key.order(:id).last
      last_translation_id = Translation.order(:id).last
      SectionKeyCreator.new.perform(@section.id, "<p>test</p>", 0)

      expect(Key.order(:id).last).to         eql(last_key_id)
      expect(Translation.order(:id).last).to eql(last_translation_id)
    end

    it "adds new required Translations and removes old unnecessary ones while keeping the unnecessary but translated Translations" do
      SectionKeyCreator.new.perform(@section.id, "<p>test</p>", 0)
      expect(@section.reload.translations.map(&:rfc5646_locale).sort).to eql(%w(en fr ja es).sort)

      @article.update! targeted_rfc5646_locales: { 'fr' => true, 'tr' => true, 'es' => false }
      SectionKeyCreator.new.perform(@section.id, "<p>test</p>", 0)
      expect(@section.reload.translations.map(&:rfc5646_locale).sort).to eql(%w(en fr tr es).sort)
    end
  end

  describe "#generate_key_name" do
    it "generates the key name using the index and the sha info" do
      expect(SectionKeyCreator.generate_key_name("hello", 7)).to eql("7:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    end
  end
end
