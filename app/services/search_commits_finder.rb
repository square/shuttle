# Copyright 2016 Square Inc.
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

class SearchCommitsFinder
  attr_reader :params
  include Elasticsearch::DSL

  def initialize(params)
    @params = params
  end

  def search_query
    sha = params[:sha]
    project_id = params[:project_id].to_i
    limit = params.fetch(:limit, 50)

    search {
      query do
        filtered do
          filter do
            bool do
              must { prefix revision: sha } if sha
              must { term project_id: project_id } if project_id > 0
              must { match_all }
            end
          end
        end
      end

      size limit
      sort { by :created_at, order: 'desc' }
    }.to_hash
  end

  def find_commits
    commits_in_es = Elasticsearch::Model.search(search_query, Commit).results
    commits = Commit.where(id: commits_in_es.map(&:id)).includes(:project)
    SortingHelper.order_by_elasticsearch_result_order(commits, commits_in_es)
  end
end