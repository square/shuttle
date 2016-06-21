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
    query_filter = @params[:filter]
    status       = @params[:status]
    offset       = @params[:offset].to_i
    project_id   = @params[:project_id]
    limit        = @params.fetch(:limit, PER_PAGE)
    not_elastic  = @params[:not_elastic_search]
    hidden_keys  = @params[:hidden_in_search]

    search {
      query do
        filtered do
          if query_filter.present? && !not_elastic
            query do
              match 'original_key' do
                query query_filter
                operator 'and'
              end
            end
          end
          filter do
            bool do
              must { term original_key_exact: query_filter } if query_filter && not_elastic
              must { term project_id: project_id }
              must { term ready: status } unless status.blank?
              hidden_keys ? must { term hidden_in_search: true } : must { term hidden_in_search: false }
            end
          end
        end
      end
      sort { by :original_key, order: 'asc' } unless query_filter.present?
      from offset
      size limit
    }.to_hash
  end

  def find_keys
    keys_in_es = Elasticsearch::Model.search(search_query, Key).results
    keys = Key.where(id: keys_in_es.map(&:id)).includes(:translations, :project)
    SortingHelper.order_by_elasticsearch_result_order(keys, keys_in_es)
  end
end