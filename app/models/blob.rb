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

# Represents a Git blob found in a Project and imported. A Blob record is
# created to indicate that this blob has already been scanned for strings,
# optimizing future imports.
#
# Associations
# ============
#
# |           |                                                      |
# |:----------|:-----------------------------------------------------|
# | `project` | The {Project} whose repository this blob belongs to. |
# | `keys`    | The {Key Keys} found in this blob.                   |
# | `commits` | The {Commit Commits} with this blob.                 |
#
# Fields
# ======
#
# |           |                                                                                                                                                                         |
# |:----------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
# | `sha`     | The Git identifier for the blob.                                                                                                                                        |
# | `path`    | The file path for the blob.                                                                                                                                             |
# | `parsed`  | If `true`, at least one worker finished parsing the {Key Keys} for this blob. Set to true when {Commit commit} import is finished if parsing the blob didn't error out. |
# | `errored` | If `true`, parsing this blob has failed. Defaults to false.                                                                                                             |

class Blob < ActiveRecord::Base
  belongs_to :project, inverse_of: :blobs
  has_many :blobs_keys, inverse_of: :blob, dependent: :delete_all
  has_many :keys, through: :blobs_keys
  has_many :blobs_commits, inverse_of: :blob, dependent: :delete_all
  has_many :commits, through: :blobs_commits

  extend DigestField
  digest_field :path, scope: :with_path

  validates :project,
            presence: true
  validates :sha,
            presence: true,
            uniqueness: {scope: [:project_id, :path_sha_raw], on: :create}
  validates :path,
            presence: true

  attr_readonly :project_id, :sha, :path_sha_raw

  # Scopes
  scope :with_sha, -> (s) { where(sha: s) }

  # Searches the blob for translatable strings, creates or updates Translations,
  # and associates them with this Blob. Imported strings are approved by
  # default. If the base locale is provided (or no locale), pending Translations
  # for the Project's other locales are also created (and filled with 100%
  # matches if possible).
  #
  # @param [Class] importer The Importer::Base subclass to process this blob.
  # @param [Commit] commit New Keys will be added to this Commit's `keys` association.
  # @raise [Git::BlobNotFoundError] If the blob could not be found in the Git
  #   repository.

  def import_strings(importer, commit)
    blob! # make sure blob exists
    importer.new(self, commit).import
  end

  # @return [Git::Object::Blob] The Git blob this Blob represents.

  def blob
    project.repo.object(sha)
  end

  # Same as {#blob}, but fetches the repository of the blob SHA isn't found.
  #
  # @return [Git::Object::Blob] The Git blob this Blob represents.
  # @raise [Git::BlobNotFoundError] If the blob could not be found in the Git
  #   repository.

  def blob!
    unless blob_object = project.find_or_fetch_git_object(sha)
      raise Git::BlobNotFoundError, sha
    end
    blob_object
  end
end
