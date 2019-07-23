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

  def initialize(params)
    @params = params
  end

  def search_query
    query_params = []

    query_params << { prefix: { revision: params[:sha] } } if params[:sha]
    query_params << { term: { project_id: params[:project_id].to_i } } if params[:project_id].present?
    query_params << { bool: { must: { match_all: {} } } }

    query = CommitsIndex.filter(query_params)
    query = query.order(created_at: :desc)
    query = query.limit(params.fetch(:limit, 50))

    return query
  end

  def find_commits
    search_query.load(scope: -> { includes(:project) }).objects
  end
end
