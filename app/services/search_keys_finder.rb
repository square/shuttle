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

class SearchKeysFinder
  # The number of records to return by default.
  PER_PAGE = 50
  include Elasticsearch::DSL

  def initialize(user, params)
    @user = user
    @params = params
  end

  def search_query
    query_params = []
    text_to_search = @params[:filter]
    if text_to_search.present?
      if !@params[:not_elastic_search]
        query_params << { match: { original_key: { query: text_to_search, operator: 'and' } } }
      else
        query_params << { term: { original_key_exact: text_to_search } }
      end
    end

    filter_params = []
    filter_params << { term: { project_id: @params[:project_id].to_i } } if @params[:project_id].present?
    filter_params << { term: { ready: @params[:status].to_b } } if @params[:status].present?
    filter_params << { term: { hidden_in_search: @params[:hidden_in_search].to_b } }

    query = KeysIndex.query(query_params).filter(filter_params)
    query = query.order(original_key_exact: :asc) if @params[:filter].blank?
    query = query.offset(@params[:offset].to_i).limit(@params.fetch(:limit, PER_PAGE))

    return query
  end

  def find_keys
    search_query.load(scope: -> { includes(:translations, :project) }).objects
  end
end
