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

require 'sidekiq_locking'

# Worker that recalculates Commit readiness and statistics such as translation counts.

class CommitRecalculator
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit to process.

  def perform(commit_id)
    commit = Commit.find(commit_id)

    commit.recalculate_ready!

    # recalculate stats
    Commit.flush_memoizations(commit)
    commit.translations_done # this will memoize stats for 1 common case where no locale is specified (i.e. all locales applicable to this commit)
  end

  include SidekiqLocking
end
