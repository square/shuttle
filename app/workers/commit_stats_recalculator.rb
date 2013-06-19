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

require 'sidekiq_locking'

# Worker that recalculates Commit statistics. Recalculates translation counts
# for a Commit.

class CommitStatsRecalculator
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit to process.

  def perform(commit_id)
    commit = Commit.find(commit_id)
    Commit.flush_memoizations(commit)

    commit.translations_done
    commit.translations_total
    commit.translations_new
    commit.translations_pending

    commit.strings_total

    commit.words_new
    commit.words_pending

    commit.keys.find_each(&:recalculate_ready!)
    commit.recalculate_ready!
    commit.save!
  end

  include SidekiqLocking
end
