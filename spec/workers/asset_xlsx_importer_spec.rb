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

RSpec.describe AssetXlsxImporter do
  describe "#perform" do
    before :each do
      allow_any_instance_of(AssetImporter::Finisher).to receive(:on_success) # prevent import from finishing
      @asset = FactoryBot.create(:asset)
      AssetXlsxImporter.new.import(@asset.id)
      @asset.reload
    end

    after :each do
      # this is needed because there is a foreign key on assets
      @asset.destroy!
    end

    it 'creates the correct number of keys' do
      expect(@asset.keys.count).to eq 1
    end

    it 'creates the correct number of translation' do
      expect(@asset.translations.count).to eq 2
    end

    it 'sets the key to the correct name' do
      expect(@asset.keys.first.key).to eq "#{@asset.id}-#{@asset.file_name.downcase}-sheet0-row1-col1"
    end
  end
end
