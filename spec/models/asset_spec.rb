# Copyright 2018 Square Inc.
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
#    limitations under the License.require 'rails_helper'
require 'rails_helper'
require 'models/concerns/common_locale_logic_spec'

RSpec.describe Asset, type: :model do
  describe '[before_validations on create]' do
    it 'copies base_rfc5646_locale from project if it is blank' do
      project = FactoryBot.create(:project, base_rfc5646_locale: 'es')
      asset = FactoryBot.create(:asset, base_rfc5646_locale: '', project: project)
      expect(asset.base_rfc5646_locale).to eql('es')
    end

    it 'copies targeted_rfc5646_locales from project if it is blank' do
      project = FactoryBot.create(:project, targeted_rfc5646_locales: {'fr' => true})
      asset = FactoryBot.create(:asset, targeted_rfc5646_locales: {}, project: project)
      expect(asset.targeted_rfc5646_locales).to eql({'fr' => true})
    end

    it 'should use targeted_rfc5646_locales specified' do
      project = FactoryBot.create(:project, targeted_rfc5646_locales: {'fr' => true})
      asset = FactoryBot.create(:asset, targeted_rfc5646_locales: {'it' => true}, project: project)
      expect(asset.targeted_rfc5646_locales).to eql({'it' => true})
    end
  end

  describe '[validations]' do
    it { is_expected.to have_attached_file(:file) }
    it { is_expected.to validate_attachment_presence(:file) }
    it { is_expected.to validate_attachment_content_type(:file).allowing(Asset::CONTENT_TYPES) }

    it 'does not allow saving without a name' do
      asset = FactoryBot.build(:asset, name: nil).tap(&:save)
      expect(asset).to_not be_persisted
      expect(asset.errors.full_messages).to eq(["Name can’t be blank"])
    end

    it 'does not allow saving without a file name' do
      asset = FactoryBot.build(:asset, file_name: nil).tap(&:save)
      expect(asset).to_not be_persisted
      expect(asset.errors.full_messages).to eq(["File name can’t be blank"])
    end

    it 'doesn\'t allow creating 2 Assets in the same project with the same name' do
      asset = FactoryBot.create(:asset, name: 'foo')
      asset_new = FactoryBot.build(:asset, name: 'foo', project: asset.project).tap(&:save)
      expect(asset_new).to_not be_persisted
      expect(asset_new.errors.messages).to eql({:name =>["already taken"]})
    end

    it 'allows creating 2 Assets with the same name under different projects' do
      FactoryBot.create(:asset, name: 'foo')
      asset_new = FactoryBot.build(:asset, name: 'foo', project: FactoryBot.create(:project)).tap(&:save)
      expect(asset_new).to be_persisted
      expect(asset_new.errors).to_not be_any
    end

    it 'doesn\'t allow updating base_rfc5646_locale to be blank' do
      project = FactoryBot.create(:project, base_rfc5646_locale: 'es')
      asset = FactoryBot.create(:asset, project: project)
      asset.update base_rfc5646_locale: nil
      expect(asset.errors.full_messages).to include("source locale can’t be blank")
      expect(asset.reload.base_rfc5646_locale).to eql('es')
      asset.update base_rfc5646_locale: ''
      expect(asset.errors.full_messages).to include("source locale can’t be blank")
      expect(asset.reload.base_rfc5646_locale).to eql('es')
    end

    it "doesn't allow updating targeted_rfc5646_locales to be blank" do
      project = FactoryBot.create(:project, targeted_rfc5646_locales: {'fr' => true})
      asset = FactoryBot.create(:asset, project: project)
      asset.update targeted_rfc5646_locales: nil
      expect(asset.errors.full_messages).to include("targeted localizations can’t be blank")
      expect(asset.reload.targeted_rfc5646_locales).to eql({'fr' => true})
      asset.update targeted_rfc5646_locales: {}
      expect(asset.errors.full_messages).to include("targeted localizations can’t be blank")
      expect(asset.reload.targeted_rfc5646_locales).to eql({'fr' => true})
    end

    it "doesn't allow name to be 'new'" do
      asset = FactoryBot.build(:asset, name: 'new').tap(&:save)
      expect(asset.errors.full_messages).to include("Name reserved")
    end
  end

  describe '[#update_import_starting_fields]' do
    it 'should update loading and ready flags' do
      asset = FactoryBot.create(:asset)
      asset.update_import_starting_fields!

      expect(asset.ready).to be false
      expect(asset.loading).to be true
    end
  end

  describe "#full_reset_ready!" do
    before(:each) { allow_any_instance_of(Asset).to receive(:import!) } # prevent auto imports

    it "resets the ready field of the Article and all of its Keys" do
      asset = FactoryBot.create(:asset, name: "test", ready: true)

      k1 = FactoryBot.create(:key, ready: true)
      k2 = FactoryBot.create(:key, ready: true)
      k3 = FactoryBot.create(:key, ready: true)

      asset.keys = [k1, k2, k3]

      asset.full_reset_ready!
      expect(asset).to_not be_ready
      expect(asset.keys.ready.exists?).to be_falsey
    end
  end

  describe "[#import!]" do
    it "resets ready fields, and calls AssetImporter" do
      asset = FactoryBot.create(:asset, name: "test", ready: true)

      FactoryBot.create(:key, project: asset.project, ready: true)
      FactoryBot.create(:key, project: asset.project, ready: true)
      FactoryBot.create(:key, project: asset.project, ready: true)

      expect(AssetImporter).to receive(:perform_once).with(asset.id).once
      allow_any_instance_of(AssetImporter::Finisher).to receive(:on_success)

      asset.import!
      asset.reload

      expect(asset).to_not be_ready
      expect(asset.loading).to be true
      expect(asset.keys.ready.exists?).to be false
    end

    it "raises a Asset::LastImportNotFinished if the previous import is not yet finished" do
      asset = FactoryBot.create(:asset)
      asset.update! loading: true
      expect { asset.import! }.to raise_error(Asset::LastImportNotFinished)
    end
  end
end
