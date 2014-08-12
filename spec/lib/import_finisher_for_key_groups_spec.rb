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
require 'sidekiq/testing/inline'

describe ImportFinisherForKeyGroups do
  describe "#on_success" do
    before :each do
      # creation triggers the initial import
      @key_group = FactoryGirl.create(:key_group, source_copy: "<p>hello</p><p>world</p>", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
      expect(@key_group.reload.keys.count).to eql(2)
      expect(@key_group.translations.count).to eql(8)
      @key_group.reload
    end

    it "sets KeyGroup's ready = false if this is an initial import" do
      expect(@key_group).to_not be_ready
    end

    it "sets KeyGroup's ready = false if this is a re-import and there are not-approved translations" do
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id}) # finish re-import
      expect(@key_group).to_not be_ready
    end

    it "sets KeyGroup's ready = true at the end of a re-import if all translations were  already approved" do
      @key_group.translations.in_locale(*@key_group.required_locales).each do |translation|
        translation.update! copy: "<p>test</p>", approved: true
      end
      @key_group.reload.update! ready: false

      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id}) # finish re-import
      expect(@key_group.reload).to be_ready
    end

    it "sets loading to false" do
      @key_group.update! loading: true
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id})
      expect(@key_group.reload).to_not be_loading
    end

    it "sets import_batch_id to false" do
      @key_group.update! import_batch_id: "something"
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id})
      expect(@key_group.reload.import_batch_id).to be_nil
    end

    it "sets first_import_finished_at at the end of the first import, and doesn't set it again on re-imports" do
      @key_group.update! first_import_finished_at: nil # clear this field for a clean start
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id})

      original_first_import_finished_at = @key_group.reload.first_import_finished_at
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id})
      expect(@key_group.reload.first_import_finished_at).to eql(original_first_import_finished_at)
    end

    it "sets last_import_finished_at at the end of the last import, and re-sets it again on every re-import" do
      expect(@key_group.last_import_finished_at).to_not be_nil
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id})

      original_last_import_finished_at = @key_group.reload.last_import_finished_at
      ImportFinisherForKeyGroups.new.on_success(nil, {'key_group_id' => @key_group.id})
      expect(@key_group.reload.last_import_finished_at).to_not eql(original_last_import_finished_at)
    end
  end

  describe "#recalculate_full_readiness!" do
    before :each do
      @key_group = FactoryGirl.create(:key_group, ready: false, source_copy: "<p>hello</p><p>world</p>", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
      expect(@key_group.reload.keys.count).to eql(2)
      expect(@key_group.translations.count).to eql(8)
      @key_group.keys.update_all ready: false
    end

    it "doesn't run KeyReadinessRecalculator (for performance reasons)" do
      expect(KeyReadinessRecalculator).to_not receive(:perform_once)
      ImportFinisherForKeyGroups.new.send :recalculate_full_readiness!, @key_group
    end

    it "sets KeyGroup's and KeyGroup's Keys' ready field to true if all required Translations are already approved" do
      # This case will be observed during re-imports all the time

      # approve all required translations
      @key_group.translations.in_locale(*@key_group.required_locales).each do |translation|
        translation.update! copy: "<p>test</p>", approved: true
      end

      # set all ready = false
      @key_group.reload.keys.update_all ready: false
      @key_group.update! ready: false

      # expect to see all ready = false (making sure no callback updated the ready fields)
      @key_group.reload.keys.each do |key|
        expect(key).to_not be_ready
      end
      expect(@key_group).to_not be_ready

      ImportFinisherForKeyGroups.new.send :recalculate_full_readiness!, @key_group

      # expect to see all ready = true
      @key_group.reload.keys.each do |key|
        expect(key).to be_ready
      end
      expect(@key_group).to be_ready
    end

    it "sets KeyGroup's ready field to false if not all keys are ready" do
      @key_group.reload.keys.update_all ready: false
      @key_group.update! ready: true

      expect(@key_group).to be_ready

      ImportFinisherForKeyGroups.new.send :recalculate_full_readiness!, @key_group

      expect(@key_group).to_not be_ready
    end
  end
end
