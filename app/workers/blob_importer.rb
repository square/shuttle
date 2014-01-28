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
  # @param [Fixnum] project_id The ID of a Project.
  # @param [Fixnum] sha The SHA of a blob in the Project's repository.
  # @param [String] path The path to the blob being imported, in the repository.
  # @param [Fixnum] commit_id The ID of the Commit with this blob.
  # @param [String] rfc5646_locale The RFC 5646 code of a locale to import
  #   existing translations from. If `nil`, the base locale is imported as
  #   base translations.

  def perform(importer, project_id, sha, path, commit_id, rfc5646_locale)
    begin
      commit   = Commit.find_by_id(commit_id)
      locale   = rfc5646_locale ? Locale.from_rfc5646(rfc5646_locale) : nil
      project  = Project.find(project_id)
      blob     = project.blobs.with_sha(sha).first!

      if blob.blob.nil?
        # for whatever reason sometimes the blob is not accessible; try again in
        # 5 minutes
        commit.add_worker! BlobImporter.perform_in(5.minutes, importer, project_id, sha, path, commit_id, rfc5646_locale)
        return
      end

      importer = Importer::Base.find_by_ident(importer)

      blob.import_strings importer,
                          path,
                          commit: commit,
                          locale: locale

    ensure
      commit.try! :remove_worker!, jid
    end
  end

  include SidekiqLocking
end
