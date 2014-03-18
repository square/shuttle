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

# Worker that recalculates {Commit} statistics. Finds all Commits that include a
# {Key}, and recalculates translation counts for those Commits.

class KeyStatsRecalculator
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] key_id The ID of a Key.

  def perform(key_id)
    query = <<-SQL
      SELECT commit_id
        FROM commits_keys
        WHERE key_id = #{Commit.connection.quote key_id}
    SQL

    Commit.connection.select_rows(query).flatten.each do |commit_id|
      CommitStatsRecalculator.perform_once commit_id.to_i
    end
  end

  include SidekiqLocking
end
