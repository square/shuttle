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

require 'fileutils'
require 'sidekiq_locking'

# Precompiles localized files and stores them in the public directory for cached
# download later.

class LocalizePrecompiler
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit to localize.

  def perform(commit_id)
    commit = Commit.find(commit_id)
    Shuttle::Redis.set key(commit), Compiler.new(commit).localize(force: true).io.read
  rescue Compiler::CommitNotReadyError
    # the commit was probably "downgraded" from ready between when the job was
    # queued and when it was started. ignore.
  end

  include SidekiqLocking

  # Returns the Redis key for a cached localized tarball.
  #
  # @param [Commit] commit A commit that was localized.
  # @return [String] The key for the cached localization, if it exists.

  def key(commit)
    "localize:#{commit.project_id}:#{commit.id}"
  end
end
