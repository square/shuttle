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

namespace :maintenance do
  desc "Cleans old or errored commits from Shuttle"
  task cleanup_commits: :environment do
    CommitsCleaner.perform_async
  end

  desc "Cleans up commits that have been deleted from the repository"
  task reap_deleted_commits: :environment do
    Commit.includes(:project).find_each do |c|
      begin
        c.commit!
      rescue Git::CommitNotFoundError
        c.destroy
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        next
      end
    end
  end
end
