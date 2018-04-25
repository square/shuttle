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
  include Elasticsearch::DSL

  # The number of records to return by default.
  PER_PAGE = 50

  def initialize(form, commit)
    @commit = commit
    @form = form
  end

  def search_query
    query_filter = form[:filter]
    status = form[:status]
    key_ids = commit.keys.pluck(:id)
    current_page = page

    search {
      query do
        filtered do
          if query_filter.present?
            query do
              match 'original_key' do
                query query_filter
                operator 'and'
              end
            end
          end
          filter do
            bool do
              must { ids values: key_ids }
              case status
              when 'approved'
                must { term ready: 1 }
              when 'pending'
                must { term ready: 0 }
              end
            end
          end
        end
      end
      sort { by :original_key_exact, order: 'asc' } unless query_filter
      from (current_page - 1) * PER_PAGE
      size PER_PAGE
    }.to_hash
  end

  def page
    form.fetch(:page, 1).to_i
  end

  def find_keys
    keys_in_es = Elasticsearch::Model.search(search_query, Key).results

    keys = Key.where(id: keys_in_es.map(&:id))
              .where('commits_keys.commit_id': commit.id)
              .includes(:translations, :commits_keys)
              .order('commits_keys.created_at asc, original_key asc')

    # Don't sort the keys since they are sorted in the line above
    PaginatableObjects.new(keys, keys_in_es, page, PER_PAGE, false)
  end
end
