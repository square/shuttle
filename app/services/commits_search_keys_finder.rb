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

    Key.search(load: {include: [:translations]}) do
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
  end
end