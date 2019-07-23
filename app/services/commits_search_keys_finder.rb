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
require 'paginatable_objects'

class CommitsSearchKeysFinder

  attr_reader :commit, :form

  # The number of records to return by default.
  PER_PAGE = 50

  def initialize(form, commit)
    @commit = commit
    @form = form
  end

  def search_query
    query_params = []
    query_params << { match: { original_key: { query: form[:filter], operator: 'and'} } } if form[:filter].present?

    filter_params = []
    filter_params << { ids: { values: commit.keys.pluck(:id) } }
    filter_params << { term: { ready: true } } if form[:status] == 'approved'
    filter_params << { term: { ready: false } } if form[:status] == 'pending'

    query = KeysIndex.query(query_params).filter(filter_params).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    query = query.order(original_key_exact: { order: :asc }) unless form[:filter]

    return query
  end

  def page
    form.fetch(:page, 1).to_i
  end

  def find_keys
    keys = search_query.load(scope: -> { includes(:translations, :commits_keys) })
    return PaginatableObjects.new(keys, page, PER_PAGE)
  end
end
