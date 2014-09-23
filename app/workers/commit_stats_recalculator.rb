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
    commit.recalculate_stats!

    ready_keys, not_ready_keys = commit.keys.includes(:project, :translations).partition(&:should_become_ready?)

    ready_keys.in_groups_of(100, false) { |group| Key.where(id: group.map(&:id)).update_all(ready: true) }
    not_ready_keys.in_groups_of(100, false) { |group| Key.where(id: group.map(&:id)).update_all(ready: false) }

    # the ES mapping loads all the commits_keys, this is slow
    # we can preload all the commits_keys for all commits, and partition them into
    # the correct commits
    commit.keys.find_in_batches do |keys|
      commits_by_key = CommitsKey.connection.select_rows(CommitsKey.select('commit_id, key_id').where(key_id: keys.map(&:id)).to_sql).inject({}) do |hsh, (commit_id, key_id)|
        hsh[key_id.to_i] ||= Set.new
        hsh[key_id.to_i] << commit_id.to_i
        hsh
      end
      # now set batched_commit_ids for each key
      keys.each { |key| key.batched_commit_ids = commits_by_key[key.id] || Set.new }
      # and run the import
      Key.tire.index.import keys
    end

    commit.recalculate_ready!
    commit.save!
  end

  include SidekiqLocking
end
