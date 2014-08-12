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

describe KeyGroup do

  # ======== START BASIC CRUD RELATED CODE =============================================================================
  describe "[validations]" do
    it "doesn't allow creating 2 KeyGroups in the same project with the same key" do
      key_group = FactoryGirl.create(:key_group, key: "hello")
      key_group_new = FactoryGirl.build(:key_group, key: "hello", project: key_group.project)
      key_group_new.save
      expect(key_group_new).to_not be_persisted
      expect(key_group_new.errors.messages).to eql({:key_sha_raw=>["already taken"]})
    end

    it "allows creating 2 KeyGroups with the same key under different projects" do
      FactoryGirl.create(:key_group, key: "hello")
      key_group_new = FactoryGirl.build(:key_group, key: "hello", project: FactoryGirl.create(:project))
      key_group_new.save
      expect(key_group_new).to be_persisted
      expect(key_group_new.errors).to_not be_any
    end

    it "doesn't allow updating the source of a KeyGroup if there is an unfinished import" do
      key_group = FactoryGirl.create(:key_group, source_copy: "hello")

      # fake it so that the first import appears to not have finished
      key_group.update! last_import_requested_at: 10.minutes.ago, last_import_finished_at: nil
      key_group.update source_copy: "hi"
      expect(key_group.errors.messages).to eql({:base => ["latest requested import is not yet finished"]})

      # fake it so that the first import appears to have finished
      key_group.reload.update! last_import_requested_at: 10.minutes.ago, last_import_finished_at: 15.minutes.ago
      key_group.update source_copy: "hi"
      expect(key_group.errors.messages).to eql({:base => ["latest requested import is not yet finished"]})
    end

    it "allows updating not import requiring fields of a KeyGroup such as email and description even if there is an unfinished import" do
      key_group = FactoryGirl.create(:key_group, email: "test@example.com", description: "desc")

      # fake it so that the first import appears to not have finished
      key_group.update email: "test2@example.com", description: "desc2"
      expect(key_group.errors).to_not be_any
    end

    it "doesn't allow creating without a key" do
      key_group = FactoryGirl.build(:key_group, key: nil)
      key_group.save
      expect(key_group).to_not be_persisted
      expect(key_group.errors.messages).to eql({:key_sha=>["is not a valid SHA2 digest"], :key=>["can’t be blank"], :key_sha_raw=>["can’t be blank"]})
    end
  end
  # ======== END BASIC CRUD RELATED CODE ===============================================================================

  # ======== START LOCALE RELATED CODE =================================================================================
  it_behaves_like "CommonLocaleLogic"

  describe "#base_locale" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil, base_rfc5646_locale: 'en') }

    it "returns the base_locale of the KeyGroup if it is set for the KeyGroup" do
      key_group = FactoryGirl.create(:key_group, project: project, base_rfc5646_locale: 'en-US')
      expect(key_group.base_locale).to eql(Locale.from_rfc5646('en-US'))
    end

    it "returns the base_locale of the Project if KeyGroup's base_locale is not set" do
      key_group = FactoryGirl.create(:key_group, project: project)
      expect(key_group.base_locale).to eql(Locale.from_rfc5646('en'))
    end
  end

  describe "#locale_requirements" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true } ) }

    it "returns the locale_requirements of the KeyGroup if they are set for the KeyGroup" do
      key_group = FactoryGirl.create(:key_group, project: project, targeted_rfc5646_locales: { 'ja' => true })
      expect(key_group.locale_requirements).to eql({ Locale.from_rfc5646('ja') => true })
    end

    it "returns the locale_requirements of the Project if KeyGroup's locale_requirements are not set" do
      key_group = FactoryGirl.create(:key_group, project: project)
      expect(key_group.locale_requirements).to eql({ Locale.from_rfc5646('fr') => true })
    end
  end
  # ======== END LOCALE RELATED CODE ===================================================================================


  # ======== START KEY & READINESS RELATED CODE ========================================================================
  describe "#find_by_key" do
    it "returns nil if the given string key is nil" do
      expect(KeyGroup.find_by_key(nil)).to be_nil
    end

    it "returns nil if no KeyGroup matches the given string key" do
      KeyGroup.delete_all
      expect(KeyGroup.find_by_key("doesnotexist")).to be_nil
    end

    it "returns the KeyGroup if key matches one" do
      key_group = FactoryGirl.create(:key_group, key: "exists")
      expect(KeyGroup.find_by_key("exists")).to eql(key_group)
    end

    it "returns the KeyGroup if key matches one in the same project" do
      KeyGroup.delete_all
      project = FactoryGirl.create(:project)
      key_group = FactoryGirl.create(:key_group, key: "exists", project: project)
      expect(project.key_groups.find_by_key("exists")).to eql(key_group)
    end

    it "returns nil if there is a KeyGroup with same key, but under a different project" do
      key_group = FactoryGirl.create(:key_group, key: "exists")
      expect(FactoryGirl.create(:project).key_groups.find_by_key("exists")).to be_nil
    end
  end

  describe "#active_keys" do
    it "returns the active keys (keys which has their index_in_key_group set)" do
      key_group = FactoryGirl.build(:key_group, key: "test")
      key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      key_group.save!
      expect(key_group.keys.count).to eql(0)

      active_key0 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 0)
      active_key1 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 1)
      inactive_key = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: nil)

      expect(key_group.reload.keys.to_a.sort).to eql([active_key0, active_key1, inactive_key].sort)
      expect(key_group.active_keys.to_a.sort).to eql([active_key0, active_key1].sort)
    end
  end

  describe "#active_translations" do
    it "returns the active translations (translations under keys which has their index_in_key_group set)" do
      key_group = FactoryGirl.build(:key_group, key: "test", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true })
      key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      key_group.save!
      expect(key_group.keys.count).to eql(0)

      active_key0 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 0)
      active_key1 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 1)
      inactive_key = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: nil)

      active_t0 = FactoryGirl.create(:translation, key: active_key0, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      active_t1 = FactoryGirl.create(:translation, key: active_key0, source_rfc5646_locale: 'en', rfc5646_locale: 'fr')
      active_t2 = FactoryGirl.create(:translation, key: active_key1, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      active_t3 = FactoryGirl.create(:translation, key: active_key1, source_rfc5646_locale: 'en', rfc5646_locale: 'fr')
      inactive_t0 = FactoryGirl.create(:translation, key: inactive_key, source_rfc5646_locale: 'en', rfc5646_locale: 'en')
      inactive_t1 = FactoryGirl.create(:translation, key: inactive_key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr')

      expect(key_group.reload.translations.to_a.sort).to eql([active_t0, active_t1, active_t2, active_t3, inactive_t0, inactive_t1].sort)
      expect(key_group.active_translations.to_a.sort).to eql([active_t0, active_t1, active_t2, active_t3].sort)
    end
  end

  describe "#sorted_active_keys_with_translations" do
    it "returns the active keys in sorted order with their translations loaded" do
      key_group = FactoryGirl.build(:key_group, key: "test")
      key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      key_group.save!
      expect(key_group.keys.count).to eql(0)

      # create active keys in an unordered way
      active_key0 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 0)
      active_key2 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 2)
      active_key1 = FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 1)
      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: nil) # this shouldn't show up in the results

      expect(key_group.reload.sorted_active_keys_with_translations.to_a).to eql([active_key0, active_key1, active_key2])

      key_group.sorted_active_keys_with_translations.each do |key|
        expect(key.translations).to be_loaded
      end
    end
  end

  describe "#recalculate_ready!" do
    before :each do
      @key_group = FactoryGirl.build(:key_group, key: "test", ready: false)
      @key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      @key_group.save!
    end

    it "sets ready=true if all active key are ready, and ignores the inactive keys" do
      FactoryGirl.create(:key, key_group: @key_group, project: @key_group.project, index_in_key_group: 0, ready: true)
      FactoryGirl.create(:key, key_group: @key_group, project: @key_group.project, index_in_key_group: 1, ready: true)
      FactoryGirl.create(:key, key_group: @key_group, project: @key_group.project, index_in_key_group: nil, ready: false)
      expect(@key_group.keys.count).to eql(3)

      expect(@key_group.reload).to_not be_ready
      @key_group.recalculate_ready!
      expect(@key_group.reload).to be_ready
    end

    it "sets first_completed_at when it becomes ready for the first time, and doesn't re-set it on later completions" do
      expect(@key_group).to_not be_ready
      @key_group.recalculate_ready!
      expect(@key_group.reload).to be_ready
      expect(@key_group.first_completed_at).to be_present
      original_first_completed_at = @key_group.first_completed_at

      Timecop.freeze(original_first_completed_at + 1.day) do
        @key_group.update! ready: false
        expect(@key_group).to_not be_ready
        @key_group.recalculate_ready!
        expect(@key_group.first_completed_at).to eql(original_first_completed_at)
      end
    end

    it "sets last_completed_at every time it becomes ready" do
      expect(@key_group).to_not be_ready
      @key_group.recalculate_ready!
      expect(@key_group.reload).to be_ready
      expect(@key_group.first_completed_at).to be_present
      original_last_completed_at = @key_group.last_completed_at

      Timecop.freeze(Date.today + 1) do
        @key_group.update! ready: false
        expect(@key_group).to_not be_ready
        @key_group.recalculate_ready!
        expect(@key_group.last_completed_at).to be_present
        expect(@key_group.last_completed_at).to_not eql(original_last_completed_at)
      end
    end
  end

  describe "#reset_ready!" do
    it "resets the ready field of the KeyGroup and all of its Keys" do
      key_group = FactoryGirl.build(:key_group, key: "test", ready: true)
      key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      key_group.save!

      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 0,   ready: true)
      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 1,   ready: true)
      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: nil, ready: true)

      key_group.reset_ready!
      expect(key_group).to_not be_ready
      expect(key_group.keys.where(ready: true).exists?).to be_false
    end
  end

  describe "#skip_key?" do
    it "skips key for a locale that is not a targeted_locale" do
      key_group = FactoryGirl.create(:key_group, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      expect(key_group.skip_key?("test", Locale.from_rfc5646('ja'))).to be_true
    end

    it "does not skip key for locales that are targeted locales" do
      key_group = FactoryGirl.create(:key_group, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      expect(key_group.skip_key?("test", Locale.from_rfc5646('fr'))).to be_false
      expect(key_group.skip_key?("test", Locale.from_rfc5646('es'))).to be_false
    end
  end
  # ======== END KEY & READINESS RELATED CODE ==========================================================================


  # ======== START IMPORT RELATED CODE =================================================================================
  describe "#import!" do
    it "updates requested_at fields, resets ready fields, and calls KeyGroupImporter" do
      key_group = FactoryGirl.create(:key_group, key: "test", ready: true)
      Key.delete_all

      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 0,   ready: true)
      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: 1,   ready: true)
      FactoryGirl.create(:key, key_group: key_group, project: key_group.project, index_in_key_group: nil, ready: true)
      key_group.reload

      expect(KeyGroupImporter).to receive(:perform_once).with(key_group.id).once

      key_group.import!

      expect(key_group.first_import_requested_at).to be_present
      expect(key_group.last_import_requested_at).to be_present
      expect(key_group).to_not be_ready
      expect(key_group.keys.where(ready: true).exists?).to be_false
    end

    it "raises a KeyGroup::LastImportNotFinished if the previous import is not yet finished" do
      key_group = FactoryGirl.create(:key_group)
      key_group.update! last_import_requested_at: 10.minutes.ago, last_import_finished_at: nil
      expect { key_group.import! }.to raise_error(KeyGroup::LastImportNotFinished)
    end
  end

  describe "#import_batch" do
    it "creates a new batch and updates import_batch_id of the KeyGroup if import_batch_id is initially nil" do
      key_group = FactoryGirl.build(:key_group, key: "test")
      key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      key_group.save!

      expect(key_group.import_batch_id).to be_nil
      expect(key_group.import_batch).to be_an_instance_of(Sidekiq::Batch)
      expect(key_group.import_batch_id).to_not be_nil
    end

    it "returns the existing import_batch if there is one" do
      key_group = FactoryGirl.build(:key_group, key: "test")
      key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      key_group.save!

      key_group.import_batch.jobs { sleep 3 }
      bid = key_group.import_batch_id
      key_group.import_batch # this should re-use the existing batch
      expect(key_group.import_batch_id).to eql(bid)
    end
  end

  describe "#update_import_requested_at!" do
    before :each do
      @key_group = FactoryGirl.build(:key_group, key: "test")
      @key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      @key_group.save!
    end

    it "sets first_import_requested_at when it is requested for the first time, and doesn't re-set it on later requests" do
      expect(@key_group.first_import_requested_at).to be_nil
      @key_group.send :update_import_requested_at!

      expect(@key_group.first_import_requested_at).to be_present
      original_first_import_requested_at = @key_group.first_import_requested_at

      Timecop.freeze(original_first_import_requested_at + 1.day) do
        @key_group.send :update_import_requested_at!
        expect(@key_group.first_import_requested_at).to eql(original_first_import_requested_at)
      end
    end

    it "sets last_import_requested_at every time it becomes ready" do
      expect(@key_group.last_import_requested_at).to be_nil
      @key_group.send :update_import_requested_at!

      expect(@key_group.last_import_requested_at).to be_present
      original_last_import_requested_at = @key_group.last_import_requested_at

      Timecop.freeze(original_last_import_requested_at + 1.day) do
        @key_group.send :update_import_requested_at!
        expect(@key_group.last_import_requested_at).to_not eql(original_last_import_requested_at)
      end
    end
  end

  describe "#update_import_starting_fields!" do
    before :each do
      @key_group = FactoryGirl.build(:key_group, key: "test")
      @key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      @key_group.save!
    end

    it "sets ready to false, loading to true, import_batch_id to nil" do
      @key_group.update! loading: false, ready: true, import_batch_id: "test"
      expect(@key_group.ready).to be_true
      expect(@key_group.import_batch_id).to eql("test")
      @key_group.send :update_import_starting_fields!
      expect(@key_group.loading).to be_true
      expect(@key_group.ready).to be_false
      expect(@key_group.import_batch_id).to be_nil
    end

    it "sets first_import_started_at when it is started for the first time, and doesn't re-set it on later requests" do
      expect(@key_group.first_import_started_at).to be_nil
      @key_group.send :update_import_starting_fields!

      expect(@key_group.first_import_started_at).to be_present
      original_first_import_started_at = @key_group.first_import_started_at

      Timecop.freeze(original_first_import_started_at + 1.day) do
        @key_group.send :update_import_starting_fields!
        expect(@key_group.first_import_started_at).to eql(original_first_import_started_at)
      end
    end

    it "sets last_import_started_at every time it is started" do
      expect(@key_group.last_import_started_at).to be_nil
      @key_group.send :update_import_starting_fields!

      expect(@key_group.last_import_started_at).to be_present
      original_last_import_started_at = @key_group.last_import_started_at

      Timecop.freeze(original_last_import_started_at + 1.day) do
        @key_group.send :update_import_starting_fields!
        expect(@key_group.last_import_started_at).to_not eql(original_last_import_started_at)
      end
    end
  end

  describe "#update_import_finishing_fields!" do
    before :each do
      @key_group = FactoryGirl.build(:key_group, key: "test")
      @key_group.stub(:import!) # prevent the import because we want to create the related keys manually
      @key_group.save!
    end

    it "sets loading to false, import_batch_id to nil" do
      @key_group.update! loading: true, import_batch_id: "123"
      @key_group.send :update_import_finishing_fields!
      expect(@key_group.loading).to be_false
      expect(@key_group.import_batch_id).to be_nil
    end

    it "sets first_import_finished_at when it is finished for the first time, and doesn't re-set it on later times" do
      expect(@key_group.first_import_finished_at).to be_nil
      @key_group.send :update_import_finishing_fields!

      expect(@key_group.first_import_finished_at).to be_present
      original_first_import_finished_at = @key_group.first_import_finished_at

      Timecop.freeze(original_first_import_finished_at + 1.day) do
        @key_group.send :update_import_finishing_fields!
        expect(@key_group.first_import_finished_at).to eql(original_first_import_finished_at)
      end
    end

    it "sets last_import_finished_at every time it is finished" do
      expect(@key_group.last_import_finished_at).to be_nil
      @key_group.send :update_import_finishing_fields!

      expect(@key_group.last_import_finished_at).to be_present
      original_last_import_finished_at = @key_group.last_import_finished_at

      Timecop.freeze(original_last_import_finished_at + 1.day) do
        @key_group.send :update_import_finishing_fields!
        expect(@key_group.last_import_finished_at).to_not eql(original_last_import_finished_at)
      end
    end
  end

  describe "#last_import_finished?" do
    before :each do
      @key_group = FactoryGirl.build(:key_group, key: "test")
      @key_group.stub(:import!) # prevent the import because we want to handle this manually
      @key_group.save!
    end

    it "returns true if neither `last_import_requested_at` nor `last_import_finished_at` is set" do
      @key_group.update! last_import_requested_at: nil, last_import_finished_at: nil
      expect(@key_group.last_import_finished?).to be_true
    end

    it "returns false if `last_import_requested_at` is set but `last_import_finished_at` is not set (after a KeyGroup is first created)" do
      @key_group.update! last_import_requested_at: Time.now, last_import_finished_at: nil
      expect(@key_group.last_import_finished?).to be_false
    end

    it "returns true if `last_import_finished_at` is greater than `last_import_requested_at` (after an import is finished)" do
      @key_group.update! last_import_requested_at: 2.minutes.ago, last_import_finished_at: 1.minutes.ago
      expect(@key_group.last_import_finished?).to be_true
    end

    it "returns false if `last_import_finished_at` is less than `last_import_requested_at` (after a re-import is scheduled)" do
      @key_group.update! last_import_requested_at: 1.minutes.ago, last_import_finished_at: 2.minutes.ago
      expect(@key_group.last_import_finished?).to be_false
    end

    it "returns true if `last_import_finished_at` is equal to `last_import_requested_at` (an import finished very fast)" do
      t = Time.now
      @key_group.update! last_import_requested_at: t, last_import_finished_at: t
      expect(@key_group.last_import_finished?).to be_true
    end
  end

  # ======== END IMPORT RELATED CODE ===================================================================================


  # ======== START ERRORS RELATED CODE =================================================================================

  describe KeyGroup::LastImportNotFinished do
    describe "#initialize" do
      it "creates a KeyGroup::LastImportNotFinished which is a kind of StandardError that has a message derived from the given KeyGroup" do
        key_group = FactoryGirl.create(:key_group)
        err = KeyGroup::LastImportNotFinished.new(key_group)
        expect(err).to be_a_kind_of(StandardError)
      end
    end
  end

  # ======== END ERRORS RELATED CODE ===================================================================================


  # ======== START INTEGRATION TESTS ===================================================================================

  it "KeyGroup's ready is set to true when the last Translation is translated, but not before" do
    key_group = FactoryGirl.create(:key_group, ready: false, source_copy: "<p>hello</p><p>world</p>", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
    expect(key_group.reload.keys.count).to eql(2)

    last_es_translation = key_group.translations.in_locale(Locale.from_rfc5646('es')).last

    (key_group.translations.to_a - [last_es_translation]).each do |translation|
      translation.update! copy: "<p>test</p>", approved: true
      expect(key_group.reload).to_not be_ready # expect KeyGroup to be not ready if not all required translations are approved
    end

    last_es_translation.update! copy: "<p>test</p>", approved: true
    expect(key_group.reload).to be_ready
  end

  it "KeyGroup's ready is set to false when all Translations were initially approved but one of them gets unapproved" do
    key_group = FactoryGirl.create(:key_group, ready: false, source_copy: "<p>hello</p><p>world</p>", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
    expect(key_group.reload.keys.count).to eql(2)

    key_group.translations.where(approved: nil).each { |translation| translation.update!  copy: "<p>test</p>", approved: true }
    expect(key_group.reload).to be_ready

    last_es_translation = key_group.translations.in_locale(Locale.from_rfc5646('es')).last

    last_es_translation.update! approved: false
    expect(key_group.reload).to_not be_ready
  end

  # ======== END INTEGRATION TESTS =====================================================================================
end
