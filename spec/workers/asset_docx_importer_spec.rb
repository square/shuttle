# Copyright 2019 Square Inc.
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

RSpec.describe AssetDocxImporter do
  describe "#perform" do
    before :each do
      @project = FactoryBot.create(:project, targeted_rfc5646_locales: { 'es' => true })
      @asset = FactoryBot.create(
        :asset,
        targeted_rfc5646_locales: { 'fr' => true },
        project: @project,
        file_name: 'word-sample2.docx',
        file: File.new("#{Rails.root}/spec/fixtures/asset_files/word-sample2.docx")
      )
      AssetDocxImporter.new.import(@asset.id)
      @asset.reload
    end

    after :each do
      # this is needed because there is a foreign key on assets
      @asset.destroy!
    end

    it 'creates the correct number of keys' do
      expect(@asset.keys.count).to eq 24
      expect(@asset.translations.count).to eq 48
    end

  end
end
