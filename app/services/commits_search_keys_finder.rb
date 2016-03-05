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

class CommitsSearchKeysFinder

  attr_reader :commit, :form

  # The number of records to return by default.
  PER_PAGE = 50

  def initialize(form, commit)
    @commit = commit
    @form = form
  end

  def find_keys
    query_filter = form[:filter]
    status       = form[:status]
    key_ids      = commit.keys.pluck(:id)
    page         = form.fetch(:page, 1).to_i

    keys_in_es = Key.search do
      if query_filter.present?
        query do
          match 'original_key', query_filter, operator: 'and'
        end
      else
        sort { by :original_key_exact, 'asc' }
      end

      filter :ids, values: key_ids

      case status
        when 'approved'
          filter :term, ready: 1
        when 'pending'
          filter :term, ready: 0
      end

      from (page - 1) * PER_PAGE
      size PER_PAGE
    end

    keys = Key.where(id: keys_in_es.map(&:id)).includes(:translations)
    PaginatableObjects.new(keys, keys_in_es, page, PER_PAGE)
  end
end