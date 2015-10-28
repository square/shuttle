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

# Creates a {Blob} if necessary and then calls {Blob#import_strings} on it.

class BlobImporter
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [String] importer The ident of an importer.
  # @param [Fixnum] blob_id The ID of the blob being imported.
  # @param [Fixnum] commit_id The ID of the Commit with this blob.

  def perform(importer, blob_id, commit_id)
    commit = Commit.find(commit_id)
    blob   = Blob.find(blob_id)

    importer = Importer::Base.find_by_ident(importer)

    blob.import_strings importer, commit
  rescue Git::CommitNotFoundError, Git::BlobNotFoundError => err
    commit.add_import_error(err, "failed in BlobImporter for commit_id #{commit_id} and blob_id #{blob_id}")
  end

  include SidekiqLocking
end
