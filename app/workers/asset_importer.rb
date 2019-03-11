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

# A worker which will start an import for an {Asset}.
# This worker is only scheduled in `import!` method of {Asset} after it's become
# known that a re-import is needed.

class AssetImporter
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker by calling `#import_strings` on the appropriate importer
  # Sets `loading` to true.
  #
  # @param [Fixnum] asset_id The ID of a Asset

  def perform(asset_id)
    asset = Asset.find(asset_id)
    # determine the correct importer to use based on file type
    if asset.file_content_type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      asset.update_import_starting_fields!

      importer = AssetXlsxImporter.new
      importer.import(asset_id)
    elsif asset.file_content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      asset.update_import_starting_fields!

      importer = AssetDocxImporter.new
      importer.import(asset_id)
    end
  end

  include SidekiqLocking

  # Contains hooks run by Sidekiq upon completion of an Asset import batch.

  class Finisher

    # Run by Sidekiq after an Asset's import batch finishes successfully.
    # Unsets the {Asset}'s `loading` flag.
    # Recalculates readiness for the {Key Keys} in the Asset, and for the {Asset} itself.

    def on_success(_status, options)
      asset = Asset.find(options['asset_id'])

      # finish loading
      asset.update_import_finishing_fields!

      Key.batch_recalculate_ready!(asset)
      AssetRecalculator.new.perform(asset.id)
      Translation.batch_refresh_elastic_search(asset)
    end
  end
end
