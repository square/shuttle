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
  extend NewRelic::Agent::MethodTracer

  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit to process.
  # @param [true, false] should_recalculate_affected_commits If `true`, also
  #   invokes {KeyReadinessRecalculator} for each key to recalculate the
  #   readiness of _other_ commits that could also be affected. This is only
  #   used for locale imports, that would cause keys to become ready as
  #   translations are imported.

  def perform(commit_id, should_recalculate_affected_commits=false)
    commit = Commit.find(commit_id)
    Commit.flush_memoizations(commit)

    commit.translations_done
    commit.translations_total
    commit.translations_new
    commit.translations_pending

    commit.strings_total

    commit.words_new
    commit.words_pending

    ready_keys, not_ready_keys = nil, nil
    self.class.trace_execution_scoped(['Custom/CommitStatsRecalculator/partition_keys']) do
      ready_keys, not_ready_keys = commit.keys.includes(:project, :translations).partition(&:should_become_ready?)
    end

    self.class.trace_execution_scoped(['Custom/CommitStatsRecalculator/update_key_readiness']) do
      ready_keys.in_groups_of(100, false) { |group| Key.where(id: group.map(&:id)).update_all(ready: true) }
      not_ready_keys.in_groups_of(100, false) { |group| Key.where(id: group.map(&:id)).update_all(ready: false) }
    end
    self.class.trace_execution_scoped(['Custom/CommitStatsRecalculator/update_key_index']) do
      commit.keys.includes(:commits_keys).each { |k| k.tire.update_index }
    end

    commit.keys.find_each { |k| KeyReadinessRecalculator.perform_once k.id } if should_recalculate_affected_commits

    commit.recalculate_ready!
    commit.save!
  end

  include SidekiqLocking
end
