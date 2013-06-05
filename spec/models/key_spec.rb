# Copyright 2013 Square Inc.
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

describe Key do
  describe "#recalculate_ready!" do
    before :all do
      @key = FactoryGirl.create(:key, project: FactoryGirl.create(:project,
                                                                  targeted_rfc5646_locales: {'en' => true, 'de' => true, 'fr' => true}))
    end

    before :each do
      @en_translation = FactoryGirl.create(:translation, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true, key: @key)
      @fr_translation = FactoryGirl.create(:translation, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: true, key: @key)
      @de_translation = FactoryGirl.create(:translation, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true, key: @key)
      @es_translation = FactoryGirl.create(:translation, rfc5646_locale: 'es', source_rfc5646_locale: 'en', approved: true, key: @key)
    end

    it "should set ready to false for keys with unapproved required translations" do
      @en_translation.update_attribute :approved, false
      @key.recalculate_ready!
      @key.should_not be_ready
    end

    it "should set ready to true for keys with all required translations approved" do
      @key.recalculate_ready!
      @key.should be_ready
    end

    it "should not care about non-required translations" do
      @es_translation.update_attribute :approved, false
      @key.recalculate_ready!
      @key.should be_ready
    end
  end

  describe "#add_pending_translations" do
    it "should add missing pending translations for any imported base translations" do
      project = FactoryGirl.create(:project,
                                   targeted_rfc5646_locales: {'en' => true, 'de' => false, 'fr' => true})
      # key1 has all translations
      key1    = FactoryGirl.create(:key, project: project)
      FactoryGirl.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'en'
      FactoryGirl.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil
      FactoryGirl.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'de', approved: nil, copy: nil

      # key2 has some translations
      key2 = FactoryGirl.create(:key, project: project)
      FactoryGirl.create :translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'en'
      FactoryGirl.create :translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil

      # key3 has no translations
      key3 = FactoryGirl.create(:key, project: project)
      FactoryGirl.create :translation, key: key3, source_rfc5646_locale: 'en', rfc5646_locale: 'en'

      key1.add_pending_translations
      key2.add_pending_translations
      key3.add_pending_translations

      key1.translations.count.should eql(3)
      key2.translations.count.should eql(3)
      key3.translations.count.should eql(3)

      key2.translations.not_base.all? do |trans|
        trans.copy.nil? && trans.approved.nil?
      end.should be_true
      key3.translations.not_base.all? do |trans|
        trans.copy.nil? && trans.approved.nil?
      end.should be_true
    end

    it "should only import included keys" do
      project = FactoryGirl.create(:project,
                                   targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                   key_inclusions:           %w(in*))

      included = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: included
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded

      included.add_pending_translations
      excluded.add_pending_translations

      included.translations.count.should eql(3)
      excluded.translations.count.should eql(1)
    end

    it "should skip excluded keys" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_exclusions:           %w(*cl*))
      key      = FactoryGirl.create(:key, key: 'key', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded

      key.add_pending_translations
      excluded.add_pending_translations

      key.translations.count.should eql(3)
      excluded.translations.count.should eql(1)
    end

    it "should skip locale-specific excluded keys" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_locale_exclusions:    {'fr' => %w(*cl*)})
      key      = FactoryGirl.create(:key, key: 'key', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded

      key.add_pending_translations
      excluded.add_pending_translations

      key.translations.count.should eql(3)
      excluded.translations.count.should eql(2)
      excluded.translations.pluck(:rfc5646_locale).sort.should eql(%w(de en-US))
    end

    it "should skip non-matching locale-specific included keys" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_locale_inclusions:    {'fr' => %w(in*)})
      included = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: included
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded

      included.add_pending_translations
      excluded.add_pending_translations

      included.translations.count.should eql(3)
      excluded.translations.count.should eql(2)
      excluded.translations.pluck(:rfc5646_locale).sort.should eql(%w(de en-US))
    end
  end

  describe "#remove_excluded_pending_translations" do
    it "should remove an empty translation not matching an included key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_exclusions:           %w(*cl*))
      key      = FactoryGirl.create(:key, key: 'key', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      key.translations.count.should eql(1)
      excluded.translations.count.should eql(0)
    end

    it "should remove an empty translation with an excluded key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_inclusions:           %w(in*))
      included = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: included, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      included.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      included.translations.count.should eql(1)
      excluded.translations.count.should eql(0)
    end

    it "should remove an empty translation with an excluded key in a locale" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_locale_exclusions:    {'fr' => %w(*cl*)})
      key      = FactoryGirl.create(:key, key: 'key', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      key.translations.count.should eql(1)
      excluded.translations.count.should eql(1)
      excluded.translations.first.rfc5646_locale.should eql('en-US')
    end

    it "should not remove a translated translation not matching an included key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_inclusions:           %w(in*))
      included = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: included, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: "hello!"

      included.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      included.translations.count.should eql(1)
      excluded.translations.count.should eql(1)
      excluded.translations.first.rfc5646_locale.should eql('fr')
    end

    it "should not remove a translated translation with an excluded key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_exclusions:           %w(*cl*))
      key      = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: "hello!"

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      key.translations.count.should eql(0)
      excluded.translations.count.should eql(1)
      excluded.translations.first.rfc5646_locale.should eql('fr')
    end
  end
end
