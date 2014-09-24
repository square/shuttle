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
        FactoryGirl.create(:key, project: project, key: "test", source_copy: "test source", key_group: nil)
        key = FactoryGirl.build(:key, project: project, key: "test", source_copy: "test source", key_group: nil)
        expect { key.save! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(key).to_not be_persisted
        expect(key.errors.messages).to eql({:key_sha_raw=>["already taken"]})
      end

      it "errors at the database layer if there are 2 concurrent `save` requests with the same key and source copy" do
        project = FactoryGirl.create(:project)
        FactoryGirl.create(:key, project: project, key: "test", source_copy: "test source", key_group: nil)
        key = FactoryGirl.build(:key, project: project, key: "test", source_copy: "test source", key_group: nil)
        key.valid?
        key.errors.clear
        expect { key.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows to create Keys with same key and source_copy as long as they are under different projects" do
        FactoryGirl.create(:key, project: FactoryGirl.create(:project), key: "test", source_copy: "test source", key_group: nil)
        key = FactoryGirl.build(:key, project: FactoryGirl.create(:project), key: "test", source_copy: "test source", key_group: nil)
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end
    end

    context "[keys_in_key_group_unique]" do
      it "errors at the Rails layer if another {Key} exists under the same {KeyGroup} with the same key" do
        key_group = FactoryGirl.create(:key_group)
        FactoryGirl.create(:key, key_group: key_group, key: "test")
        key = FactoryGirl.build(:key, key_group: key_group, key: "test")
        expect { key.save! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(key).to_not be_persisted
        expect(key.errors.messages).to eql({:key_sha_raw=>["already taken"]})
      end

      it "errors at the database layer if there are 2 concurrent `save` requests with the same key under one {KeyGroup}" do
        key_group = FactoryGirl.create(:key_group)
        FactoryGirl.create(:key, key_group: key_group, key: "test")
        key = FactoryGirl.build(:key, key_group: key_group, key: "test")
        key.valid?
        key.errors.clear
        expect { key.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows to create {Key Keys} with same key as long as they are under different {KeyGroup KeyGroups}" do
        FactoryGirl.create(:key, key_group: FactoryGirl.create(:key_group), key: "test")
        key = FactoryGirl.build(:key, key_group: FactoryGirl.create(:key_group), key: "test")
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end
    end

    context "[index_in_key_group_unique]" do
      it "errors at the Rails layer if another {Key} exists under the same {KeyGroup} with the same index_in_key_group" do
        key_group = FactoryGirl.create(:key_group)
        Key.delete_all

        FactoryGirl.create(:key, key_group: key_group, index_in_key_group: 0)
        key = FactoryGirl.build(:key, key_group: key_group, index_in_key_group: 0)
        expect { key.save! }.to raise_error(ActiveRecord::RecordInvalid)
        expect(key).to_not be_persisted
        expect(key.errors.messages).to eql({:index_in_key_group=>["already taken"]})
      end

      it "errors at the database layer if there are 2 concurrent `save` requests with the same index_in_key_group under one {KeyGroup}" do
        key_group = FactoryGirl.create(:key_group)
        Key.delete_all

        FactoryGirl.create(:key, key_group: key_group, index_in_key_group: 0)
        key = FactoryGirl.build(:key, key_group: key_group, index_in_key_group: 0)
        key.valid?
        key.errors.clear
        expect { key.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows to create {Key Keys} with same index_in_key_group as long as they are under different {KeyGroup KeyGroups}" do
        key_group1 = FactoryGirl.create(:key_group)
        key_group2 = FactoryGirl.create(:key_group)
        Key.delete_all

        FactoryGirl.create(:key, key_group: key_group1, index_in_key_group: 0)
        key = FactoryGirl.build(:key, key_group: key_group2, index_in_key_group: 0)
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end

      it "allows multiple {Keys} under the same {KeyGroup} with index_in_key_group = nil" do
        key_group = FactoryGirl.create(:key_group)
        Key.delete_all

        FactoryGirl.create(:key, key_group: key_group, index_in_key_group: nil)
        key = FactoryGirl.build(:key, key_group: key_group, index_in_key_group: nil)
        expect { key.save! }.to_not raise_error
        expect(key).to be_persisted
      end
    end
  end

  describe "#recalculate_ready!" do
    context "[for git-based projects]" do
      before :each do
        @key = FactoryGirl.create(:key, project: FactoryGirl.create(:project, targeted_rfc5646_locales: {'en' => true, 'de' => true, 'fr' => true}))
        @en_translation = FactoryGirl.create(:translation, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true, key: @key)
        @fr_translation = FactoryGirl.create(:translation, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: true, key: @key)
        @de_translation = FactoryGirl.create(:translation, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true, key: @key)
        @es_translation = FactoryGirl.create(:translation, rfc5646_locale: 'es', source_rfc5646_locale: 'en', approved: true, key: @key)
      end

      it "should set ready to false for keys with unapproved required translations" do
        @en_translation.update_attribute :approved, false
        @key.recalculate_ready!
        expect(@key).not_to be_ready
      end

      it "should set ready to true for keys with all required translations approved" do
        @key.recalculate_ready!
        expect(@key).to be_ready
      end

      it "should not care about non-required translations" do
        @es_translation.update_attribute :approved, false
        @key.recalculate_ready!
        expect(@key).to be_ready
      end
    end

    context "[for KeyGroup-based projects]" do
      before :each do
        @key = FactoryGirl.create(:key, key_group: FactoryGirl.create(:key_group, targeted_rfc5646_locales: {'en' => true, 'de' => true, 'fr' => true}))
        @en_translation = FactoryGirl.create(:translation, rfc5646_locale: 'en', source_rfc5646_locale: 'en', approved: true, key: @key)
        @fr_translation = FactoryGirl.create(:translation, rfc5646_locale: 'fr', source_rfc5646_locale: 'en', approved: true, key: @key)
        @de_translation = FactoryGirl.create(:translation, rfc5646_locale: 'de', source_rfc5646_locale: 'en', approved: true, key: @key)
        @es_translation = FactoryGirl.create(:translation, rfc5646_locale: 'es', source_rfc5646_locale: 'en', approved: true, key: @key)
      end

      it "should set ready to false for keys with unapproved required translations" do
        @en_translation.update_attribute :approved, false
        @key.recalculate_ready!
        expect(@key).not_to be_ready
      end

      it "should set ready to true for keys with all required translations approved" do
        @key.recalculate_ready!
        expect(@key).to be_ready
      end

      it "should not care about non-required translations" do
        @es_translation.update_attribute :approved, false
        @key.recalculate_ready!
        expect(@key).to be_ready
      end

      # TODO (yunus): the 2 tests below are not key-group specific, pull them out.
      # Also, they are not applicable ATM since KeyStatsRecalculator is run whether or not ready cahnegd
      # Uncomment these once that is fixed.
      #
      # it "should run KeyStatsRecalculator if readiness state changed" do
      #   @key.update_column :ready, false
      #   expect(KeyStatsRecalculator).to receive(:perform_once).once.with(@key.id)
      #   @key.recalculate_ready!
      # end
      #
      # it "should not run KeyStatsRecalculator if readiness state did not change" do
      #   @fr_translation.update_attribute :approved, false
      #   @key.update_column :ready, false
      #   expect(KeyStatsRecalculator).to_not receive(:perform_once)
      #   @key.recalculate_ready!
      # end
    end

    it "doesn't run KeyStatsRecalculator if skip_readiness_hooks is true" do
      key = FactoryGirl.create(:key)
      expect(KeyStatsRecalculator).to_not receive(:perform_once)
      key.skip_readiness_hooks = true
      key.recalculate_ready!
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

    context "[for keygroup-related keys]" do
      it "should skip key for a locale that is not a targeted locale even if it would not be skipped according to project's settings" do
        project  = FactoryGirl.create(:project,
                                      base_rfc5646_locale: 'en',
                                      targeted_rfc5646_locales: {'fr' => true})
        key_group = FactoryGirl.create(:key_group, project: project, targeted_rfc5646_locales: {'de' => true})
        key = FactoryGirl.create(:key, project: project, key_group: key_group)

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

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
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

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: included, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
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

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: nil

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(key.translations.count).to eql(1)
      expect(excluded.translations.count).to eql(1)
      expect(excluded.translations.first.rfc5646_locale).to eql('en-US')
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

      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: key, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'en-US', key: excluded, copy: nil
      FactoryGirl.create :translation, source_rfc5646_locale: 'en-US', rfc5646_locale: 'fr', key: excluded, copy: "hello!"

      key.remove_excluded_pending_translations
      excluded.remove_excluded_pending_translations

      expect(key.translations.count).to eql(0)
      expect(excluded.translations.count).to eql(1)
      expect(excluded.translations.first.rfc5646_locale).to eql('fr')
    end

    context "[for KeyGroup related keys]" do
      it "should not remove a translation in a targeted locale of the KeyGroup even if it would have been removed according to the project settings" do
        project  = FactoryGirl.create(:project,
                                      targeted_rfc5646_locales: {'en' => true, 'fr' => true},
                                      key_locale_exclusions:    {'fr' => %w(*cl*)})
        key_group = FactoryGirl.create(:key_group, project: project, targeted_rfc5646_locales: {'en' => true, 'fr' => true})
        key = FactoryGirl.create(:key, key: 'included_in_key_group_excluded_from_project', project: project, key_group: key_group)
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'en', key: key, copy: nil
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', key: key, copy: nil
        key.remove_excluded_pending_translations

        expect(key.reload.translations.count).to eql(2)
      end

      it "should not remove a translated Translation even if it's not in a targeted locale of the KeyGroup" do
        project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
        key_group = FactoryGirl.create(:key_group, project: project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
        key = FactoryGirl.create(:key, project: project, key_group: key_group)
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'ja', key: key, copy: "hey"
        key.remove_excluded_pending_translations

        expect(key.reload.translations.count).to eql(1)
      end

      it "should remove a not-translated Translation if it's not in a targeted locale of the KeyGroup" do
        project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es' => true})
        key_group = FactoryGirl.create(:key_group, project: project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'fr' => true})
        key = FactoryGirl.create(:key, project: project, key_group: key_group)
        FactoryGirl.create :translation, source_rfc5646_locale: 'en', rfc5646_locale: 'es', key: key, copy: nil
        key.remove_excluded_pending_translations

        expect(key.reload.translations.count).to eql(0)
      end
    end
  end

  describe "#should_become_ready?" do
    context "[for git-based projects]" do
      before :each do
        @project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'en' => true, 'fr' => true, 'de' => false})
        @key     = FactoryGirl.create(:key, project: @project)
        FactoryGirl.create :translation, rfc5646_locale: 'en', key: @key, approved: true
        @req_translation = FactoryGirl.create(:translation, rfc5646_locale: 'fr', key: @key, approved: true)
        FactoryGirl.create :translation, rfc5646_locale: 'de', key: @key, approved: false
      end

      context "[translations loaded]" do
        before :each do
          @key.reload.translations(true)
          expect(@key.translations).to be_loaded
        end

        it "should return true if all translations in required locales are approved" do
          expect(@key.should_become_ready?).to be_true
        end

        it "should return false if a translation in a required locale is not approved" do
          @req_translation.update_attribute :approved, nil
          @key.translations(true)
          expect(@key.should_become_ready?).to be_false
        end
      end

      context "[translations not loaded]" do
        before :each do
          @key.reload
          expect(@key.translations).not_to be_loaded
        end

        it "should return true if all translations in required locales are approved" do
          expect(@key.should_become_ready?).to be_true
        end

        it "should return false if a translation in a required locale is not approved" do
          @req_translation.update_attribute :approved, nil
          expect(@key.should_become_ready?).to be_false
        end
      end
    end

    context "[for KeyGroup based projects]" do
      before :each do
        @project = FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: {'fr' => true, 'de' => true})
        @key_group = FactoryGirl.create(:key_group, project: @project, targeted_rfc5646_locales: {'fr' => true, 'de' => false})
        @key     = FactoryGirl.create(:key, project: @project, key_group: @key_group)
        @req_translation = FactoryGirl.create(:translation, rfc5646_locale: 'fr', key: @key, approved: true)
        FactoryGirl.create :translation, rfc5646_locale: 'de', key: @key, approved: false
      end

      context "[translations loaded]" do
        before :each do
          @key.reload.translations(true)
          expect(@key.translations).to be_loaded
        end

        it "should return true if all translations in required locales are approved" do
          expect(@key.should_become_ready?).to be_true
        end

        it "should return false if a translation in a required locale is not approved" do
          @req_translation.update_attribute :approved, nil
          @key.translations(true)
          expect(@key.should_become_ready?).to be_false
        end
      end

      context "[translations not loaded]" do
        before :each do
          @key.reload
          expect(@key.translations).not_to be_loaded
        end

        it "should return true if all translations in required locales are approved" do
          expect(@key.should_become_ready?).to be_true
        end

        it "should return false if a translation in a required locale is not approved" do
          @req_translation.update_attribute :approved, nil
          expect(@key.should_become_ready?).to be_false
        end
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

    it "properly recalculates ready for keys of a given key group in batch" do
      KeyGroup.any_instance.stub(:import!)
      key_group = FactoryGirl.create(:key_group, project: @project)
      @key1.update! key_group: key_group, index_in_key_group: 0
      @key2.update! key_group: key_group, index_in_key_group: 1

      Key.batch_recalculate_ready!(key_group)
      expect(@key1.reload).to be_ready
      expect(@key2.reload).to_not be_ready
    end
  end
end
