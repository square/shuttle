# Copyright 2013 Square Inc.
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

# Join table between {Blob} and {Commit}. Indicates what blobs are accessible
# from what commits.
#
# Associations
# ------------
#
# |          |                                 |
# |:---------|:--------------------------------|
# | `blob`   | The {Blob} found in the Commit. |
# | `commit` | The {Commit} with the Blob.     |

class BlobsCommit < ActiveRecord::Base
  belongs_to :blob, foreign_key: [:project_id, :sha_raw], inverse_of: :blobs_commits
  belongs_to :commit, inverse_of: :blobs_commits
end
