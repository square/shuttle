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

require 'fileutils'
require 'sidekiq_locking'

# Precompiles localized files and stores them in the public directory for cached
# download later.

class LocalizePrecompiler
  include Sidekiq::Worker
  sidekiq_options queue: :low

  include Precompiler

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit to localize.

  def perform(commit_id)
    commit = Commit.find(commit_id)
    write_precompiled_file(path(commit)) do
      Compiler.new(commit).localize(force: true)
    end
  rescue Compiler::CommitNotReadyError
    # the commit was probably "downgraded" from ready between when the job was
    # queued and when it was started. ignore.
  end

  include SidekiqLocking

  # Returns the path to a cached localized tarball.
  #
  # @param [Commit] commit A commit that was localized.
  # @return [Pathname] The path to the cached localization, if it exists.

  def path(commit)
    dir = directory(commit)
    FileUtils.mkdir_p dir
    dir.join 'localized.tgz'
  end

  private

  def directory(commit)
    Rails.root.join 'tmp', 'cache', 'localize', Rails.env.to_s, commit.id.to_s
  end
end
