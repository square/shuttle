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

describe Key do
  context "[write constraints & validations]" do
    context "[keys_unique]" do
      it "errors at the Rails layer if another {Key} exists under the same {Project} with the same key and source copy" do
        project = FactoryGirl.create(:project)
        FactoryGirl.create(:key, project: project, key: "test", source_copy: "test source", section: nil)
        key = FactoryGirl.build(:key, project: project, key: "test", source_copy: "test source", section: nil)
        expect { key.save! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(key).to_not be_persisted
        expect(key.errors.messages).to eql({:key_sha_raw=>["already taken"]})
      end

      it "errors at the database layer if there are 2 concurrent `save` requests with the same key and source copy" do
        project = FactoryGirl.create(:project)
        FactoryGirl.create(:key, project: project, key: "test", source_copy: "test source", section: nil)
        key = FactoryGirl.build(:key, project: project, key: "test", source_copy: "test source", section: nil)
        key.valid?
        key.errors.clear
        expect { key.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows to create Keys with same key and source_copy as long as they are under different projects" do
        FactoryGirl.create(:key, project: FactoryGirl.create(:project), key: "test", source_copy: "test source", section: nil)
        key = FactoryGirl.build(:key, project: FactoryGirl.create(:project), key: "test", source_copy: "test source", section: nil)
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end
    end

    context "[keys_in_section_unique]" do
      it "errors at the Rails layer if another {Key} exists under the same {Section} with the same key" do
        section = FactoryGirl.create(:section)
        FactoryGirl.create(:key, section: section, key: "test")
        key = FactoryGirl.build(:key, section: section, key: "test")
        expect { key.save! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(key).to_not be_persisted
        expect(key.errors.messages).to eql({:key_sha_raw=>["already taken"]})
      end

      it "errors at the database layer if there are 2 concurrent `save` requests with the same key under one {Section}" do
        section = FactoryGirl.create(:section)
        FactoryGirl.create(:key, section: section, key: "test")
        key = FactoryGirl.build(:key, section: section, key: "test")
        key.valid?
        key.errors.clear
        expect { key.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows to create {Key Keys} with same key as long as they are under different {Section Sections}" do
        FactoryGirl.create(:key, section: FactoryGirl.create(:section), key: "test")
        key = FactoryGirl.build(:key, section: FactoryGirl.create(:section), key: "test")
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end
    end

    context "[index_in_section_unique]" do
      it "errors at the Rails layer if another {Key} exists under the same {Section} with the same index_in_section" do
        section = FactoryGirl.create(:section)
        Key.delete_all

        FactoryGirl.create(:key, section: section, index_in_section: 0)
        key = FactoryGirl.build(:key, section: section, index_in_section: 0)
        expect { key.save! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(key).to_not be_persisted
        expect(key.errors.messages).to eql({:index_in_section=>["already taken"]})
      end

      it "errors at the database layer if there are 2 concurrent `save` requests with the same index_in_section under one {Section}" do
        section = FactoryGirl.create(:section)
        Key.delete_all

        FactoryGirl.create(:key, section: section, index_in_section: 0)
        key = FactoryGirl.build(:key, section: section, index_in_section: 0)
        key.valid?
        key.errors.clear
        expect { key.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows to create {Key Keys} with same index_in_section as long as they are under different {Section Sections}" do
        section1 = FactoryGirl.create(:section)
        section2 = FactoryGirl.create(:section)
        Key.delete_all

        FactoryGirl.create(:key, section: section1, index_in_section: 0)
        key = FactoryGirl.build(:key, section: section2, index_in_section: 0)
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end

      it "allows multiple {Keys} under the same {Section} with index_in_section = nil" do
        section = FactoryGirl.create(:section)
        Key.delete_all

        FactoryGirl.create(:key, section: section, index_in_section: nil)
        key = FactoryGirl.build(:key, section: section, index_in_section: nil)
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end
    end
  end

  describe "#recalculate_ready!" do
    it "doesn't run KeyAncestorsRecalculator if skip_readiness_hooks is true" do
      key = FactoryGirl.create(:key)
      expect(KeyAncestorsRecalculator).to_not receive(:perform_once)
      key.skip_readiness_hooks = true
      key.recalculate_ready!
    end

    it "runs KeyAncestorsRecalculator and updates the ready state in the database" do
      key = FactoryGirl.create(:key, ready: false)
      expect(KeyAncestorsRecalculator).to receive(:perform_once)
      key.recalculate_ready!
      expect(key.reload).to be_ready
    end

    it "doesn't run KeyAncestorsRecalculator if ready doesn't change" do
      key = FactoryGirl.create(:key, ready: false)
      FactoryGirl.create(:translation, key: key, approved: nil)
      expect(KeyAncestorsRecalculator).to_not receive(:perform_once)
      key.recalculate_ready!
    end

    context "[readiness state]" do
      before :each do
        project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'ja' => true, 'fr' => true, 'es' => false})
        @key = FactoryGirl.create(:key, ready: false, project: project)
        @ja_translation = FactoryGirl.create(:translation, rfc5646_locale: 'fr', approved: nil, key: @key)
        @fr_translation = FactoryGirl.create(:translation, rfc5646_locale: 'de', approved: nil, key: @key)
        @es_translation = FactoryGirl.create(:translation, rfc5646_locale: 'es', approved: nil, key: @key)
        expect(@key.reload).to_not be_ready
      end

      it "should set ready to false for keys with unapproved required translations" do
        @key.recalculate_ready!
        expect(@key).not_to be_ready
      end

      it "should set ready to true for keys with all required translations approved, even if there are not-approved optional translations" do
        [@ja_translation, @fr_translation].each { |t| t.update! approved: true }
        @key.recalculate_ready!
        expect(@key).to be_ready
      end
    end
  end

  describe "#add_pending_translations" do
    it "should add missing pending translations (base + targeted)" do
      project = FactoryGirl.create(:project,
                                   base_rfc5646_locale: 'en',
                                   targeted_rfc5646_locales: {'en' => true, 'de' => false, 'fr' => true})
      # key1 has all translations including the base translation
      key1    = FactoryGirl.create(:key, project: project)
      FactoryGirl.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'en', approved: true, source_copy: "hi", copy: "hi"
      FactoryGirl.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil
      FactoryGirl.create :translation, key: key1, source_rfc5646_locale: 'en', rfc5646_locale: 'de', approved: nil, copy: nil

      # key2 has some translations, doesn't have the base translation
      key2 = FactoryGirl.create(:key, project: project)
      FactoryGirl.create :translation, key: key2, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', approved: nil, copy: nil

      # key3 has no translations
      key3 = FactoryGirl.create(:key, project: project)

      key1.add_pending_translations
      key2.add_pending_translations
      key3.add_pending_translations

      expect(key1.translations.count).to eql(3)
      expect(key2.translations.count).to eql(3)
      expect(key3.translations.count).to eql(3)

      expect(key2.translations.not_base.all? do |trans|
        trans.copy.nil? && trans.approved.nil?
      end).to be_true
      expect(key3.translations.not_base.all? do |trans|
        trans.copy.nil? && trans.approved.nil?
      end).to be_true

      base_translations = [key1.translations.base.first, key2.translations.base.first, key3.translations.base.first]
      expect(base_translations.all? { |trans| trans && (trans.copy == trans.source_copy) && trans.approved? }).to be_true
    end

    context "[for commit-related keys]" do
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

        expect(included.translations.count).to eql(3)
        expect(excluded.translations.count).to eql(1)
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

        expect(key.translations.count).to eql(3)
        expect(excluded.translations.count).to eql(1)
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

        expect(key.translations.count).to eql(3)
        expect(excluded.translations.count).to eql(2)
        expect(excluded.translations.pluck(:rfc5646_locale).sort).to eql(%w(de en-US))
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

        expect(included.translations.count).to eql(3)
        expect(excluded.translations.count).to eql(2)
        expect(excluded.translations.pluck(:rfc5646_locale).sort).to eql(%w(de en-US))
      end
    end

    context "[for article-bound keys]" do
      it "should skip key for a locale that is not a targeted locale even if it would not be skipped according to project's settings" do
        project  = FactoryGirl.create(:project,
                                      base_rfc5646_locale: 'en',
                                      targeted_rfc5646_locales: {'fr' => true})
        Article.any_instance.stub(:import) # prevent auto import
        article = FactoryGirl.create(:article, project: project, targeted_rfc5646_locales: {'de' => true})
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, project: project, section: section)

        key.add_pending_translations

        expect(key.translations.map(&:rfc5646_locale).sort).to eql(%w(en de).sort)
      end
    end
  end

  describe "#remove_excluded_pending_translations" do
    it "should remove an empty translation not matching an included key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_exclusions:           %w(*cl*))
      key      = FactoryGirl.create(:key, key: 'key', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: key, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(key.translations.count).to eql(1)
      expect(excluded.translations.count).to eql(0)
    end

    it "should remove an empty translation with an excluded key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_inclusions:           %w(in*))
      included = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: included, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      included.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(included.translations.count).to eql(1)
      expect(excluded.translations.count).to eql(0)
    end

    it "should remove an empty translation with an excluded key in a locale" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_locale_exclusions:    {'fr' => %w(*cl*)})
      key      = FactoryGirl.create(:key, key: 'key', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: key
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(key.translations.count).to eql(1)
      expect(excluded.translations.count).to eql(1)
      expect(excluded.translations.first.rfc5646_locale).to eql('de')
    end

    it "should not remove a translated translation not matching an included key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_inclusions:           %w(in*))
      included = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: included, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: "hello!"

      included.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(included.translations.count).to eql(1)
      expect(excluded.translations.count).to eql(1)
      expect(excluded.translations.first.rfc5646_locale).to eql('fr')
    end

    it "should not remove a translated translation with an excluded key" do
      project  = FactoryGirl.create(:project,
                                    targeted_rfc5646_locales: {'en-US' => true, 'de' => true, 'fr' => true},
                                    key_exclusions:           %w(*cl*))
      key      = FactoryGirl.create(:key, key: 'included', project: project)
      excluded = FactoryGirl.create(:key, key: 'excluded', project: project)

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: key, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'de', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: "hello!"

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(key.translations.count).to eql(0)
      expect(excluded.translations.count).to eql(1)
      expect(excluded.translations.first.rfc5646_locale).to eql('fr')
    end

    it "should remove an empty translation if it's not in project's targeted locales or in its base locale" do
      project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
      key = FactoryGirl.create(:key, project: project)
      FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'tr', key: key, copy: nil
      key.remove_excluded_pending_translations

      expect(key.reload.translations).to be_empty
    end

    it "should not remove an empty translation if it's in project's targeted locales" do
      project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
      key = FactoryGirl.create(:key, project: project)
      translation = FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'es', key: key, copy: nil
      key.remove_excluded_pending_translations

      expect(key.reload.translations.to_a).to eql([translation])
    end

    it "should not remove an empty base translation" do
      project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
      key = FactoryGirl.create(:key, project: project)
      translation = FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'en', key: key, copy: nil
      key.remove_excluded_pending_translations

      expect(key.reload.translations.to_a).to eql([translation])
    end

    context "[for Article related keys]" do
      it "should not remove a translation in a targeted locale of the Article even if it would have been removed according to the project settings" do
        project  = FactoryGirl.create(:project,
                                      targeted_rfc5646_locales: {'en' => true, 'fr' => true},
                                      key_locale_exclusions:    {'fr' => %w(*cl*)})

        Article.any_instance.stub(:import) # prevent auto import
        article = FactoryGirl.create(:article, project: project, targeted_rfc5646_locales: {'en' => true, 'fr' => true})
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, key: 'included_in_article_excluded_from_project', project: project, section: section)
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'en', key: key, copy: nil
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', key: key, copy: nil
        key.remove_excluded_pending_translations

        expect(key.reload.translations.count).to eql(2)
      end

      it "should not remove a translated Translation even if it's not in a targeted locale of the Article" do
        project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
        Article.any_instance.stub(:import) # prevent auto import
        article = FactoryGirl.create(:article, project: project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, project: project, section: section)
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'ja', key: key, copy: "hey"
        key.remove_excluded_pending_translations

        expect(key.reload.translations.count).to eql(1)
      end

      it "should remove a not-translated Translation if it's not in a targeted locale of the Article" do
        project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
        Article.any_instance.stub(:import) # prevent auto import
        article = FactoryGirl.create(:article, project: project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
        section = FactoryGirl.create(:section, article: article)
        key = FactoryGirl.create(:key, project: project, section: section)
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'es', key: key, copy: nil
        key.remove_excluded_pending_translations

        expect(key.reload.translations.count).to eql(0)
      end
    end
  end

  describe "#batch_recalculate_ready!" do
    before :each do
      @project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true}, base_rfc5646_locale: 'en')
      @key1 = FactoryGirl.create(:key, project: @project)
      @translation1 = FactoryGirl.create(:translation, key: @key1, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', copy: "fake", approved: true)
      @key2 = FactoryGirl.create(:key, project: @project)
      @translation2 = FactoryGirl.create(:translation, key: @key2, rfc5646_locale: 'fr', source_rfc5646_locale: 'en')

      @key1.update! ready: false
      @key2.update! ready: false
      expect(@key1).to_not be_ready
      expect(@key2).to_not be_ready
    end

    it "properly recalculates ready for keys of a given commit in batch" do
      commit = FactoryGirl.create(:commit, project: @project)
      commit.keys = [@key1, @key2]

      Key.batch_recalculate_ready!(commit)
      expect(@key1.reload).to be_ready
      expect(@key2.reload).to_not be_ready
    end

    it "properly recalculates ready for keys of a given project in batch" do
      Key.batch_recalculate_ready!(@project)
      expect(@key1.reload).to be_ready
      expect(@key2.reload).to_not be_ready
    end

    it "properly recalculates ready for keys of a given article in batch" do
      Article.any_instance.stub(:import!)
      article = FactoryGirl.create(:article, project: @project)
      section = FactoryGirl.create(:section, article: article)
      @key1.update! section: section, index_in_section: 0
      @key2.update! section: section, index_in_section: 1

      Key.batch_recalculate_ready!(article)
      expect(@key1.reload).to be_ready
      expect(@key2.reload).to_not be_ready
    end
  end
end
