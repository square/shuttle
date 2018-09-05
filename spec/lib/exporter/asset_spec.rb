# encoding: utf-8

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
#    limitations under the License.

require 'rails_helper'

RSpec.describe Exporter::Asset do
  before :all do
    @fr_locale = Locale.from_rfc5646('fr')
    @it_locale = Locale.from_rfc5646('it')
  end

  before(:each) do
    @project = FactoryBot.create(:project, base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: { 'fr' => true, 'it' => true })
    @asset = FactoryBot.create(:asset, ready: false, project: @project)
    AssetImporter.new.perform(@asset.id)
    AssetImporter::Finisher.new.on_success(nil, {'asset_id' => @asset.id})

    expect(@asset.reload.keys.count).to eql(1)

    @asset_fr_translations = @asset.translations.in_locale(@fr_locale)
    @asset_it_translations = @asset.translations.in_locale(@it_locale)

    @asset_fr_translations[0].update! copy: 'bonjour', approved: true
    @asset_it_translations[0].update! copy: 'ciao', approved: true

    @asset.keys.reload.each(&:recalculate_ready!)
    expect(@asset.reload).to be_ready
  end

  describe "#export" do
    it "raises InputError if no locales are provided" do
      expect { Exporter::Asset.new(@asset).send(:export, []) }.to raise_error(Exporter::Asset::InputError, "No Locale(s) Inputted")
    end

    it "raises InputError if an invalid locale in rfc5646 representation is provided" do
      expect { Exporter::Asset.new(@asset).send(:export, "fr, invalid-locale") }.to raise_error(Exporter::Asset::InputError, "Locale 'invalid-locale' could not be found.")
    end

    it "raises InputError if one of the requested locales is not a required locale" do
      expect { Exporter::Asset.new(@asset).send(:export, "fr, ja") }.to raise_error(Exporter::Asset::InputError, "Inputted locale 'ja' is not one of the required locales for this asset.")
    end

    it "raises NotReadyError if Asset is not ready" do
      @asset_fr_translations[0].update! approved: false
      @asset_fr_translations[0].key.reload.recalculate_ready!
      expect(@asset.reload).to_not be_ready
      expect { Exporter::Asset.new(@asset).send(:export) }.to raise_error(Exporter::Asset::NotReadyError)
    end

    it "returns a StringIO object when string locales are provided" do
      result = Exporter::Asset.new(@asset).send(:export, "fr, it")
      expect(result).to be_a(StringIO)
    end
  end
end
