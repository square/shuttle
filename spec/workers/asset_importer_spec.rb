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

RSpec.describe AssetImporter do
  describe "#perform" do
    before :each do
      allow_any_instance_of(AssetImporter::Finisher).to receive(:on_success) # prevent import from finishing
      @asset = FactoryBot.create(:asset)
      AssetImporter.new.perform(@asset.id)
      @asset.reload
    end

    after :each do
      # this is needed because there is a foreign key on assets
      @asset.destroy!
    end

    it 'sets ready to false' do
      expect(@asset).to_not be_ready
    end

    context '[Excel XSLX files]' do
      it 'sets loading to true' do
        expect(@asset.loading).to be true
      end

      it 'imports data from a file' do
        expect(@asset.keys.count).to eq 1
      end

      it 'sets the proper key name' do
        hashed_value = Digest::SHA1.hexdigest(@asset.keys.first.source_copy)
        expect(@asset.keys.first.original_key).to eq "#{@asset.file_name}-sheet0-row1-col1-#{hashed_value}"
      end
    end
  end
end
