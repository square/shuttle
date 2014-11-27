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

# Abstract error which should be subclassed for different object types, and
# subclass should be raised when a sha is no longer found in the Git repository.
class Git::NotFoundError < StandardError
  #   @param [String] sha The error object.
  #   @param [String] object_type The type of git object that is not found.
  def initialize(sha, object_type = "Object")
    super("#{object_type} not found in git repo: #{sha}")
  end
end

# Raised when a {Commit}'s revision is no longer found in the Git repository.
class Git::CommitNotFoundError < Git::NotFoundError
  #   @param [String] sha The error object.
  def initialize(sha)
    super(sha, "Commit")
  end
end

# Raised when a {Blob}'s sha is no longer found in the Git repository.
class Git::BlobNotFoundError < Git::NotFoundError
  #   @param [String] sha The error object.
  def initialize(sha)
    super(sha, "Blob")
  end
end
