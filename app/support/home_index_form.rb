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

# Handles Homepage's form variables.
# Puts all form variables into a `vars` hash.
# It stores some variables in the cookies hash as well, and reads them on subsequent requests.
#
# There are 3 kinds of filters and sorts:
#   - Specific to commits: `filter__sha`, `filter__project_id`, `filter__hide_exported`, `filter__hide_autoimported`, `filter__show_only_mine`
#   - Specific to articles: `name`, `filter__project_id`
#   - Not Specific, Applies to both: `offset`, `limit`, `filter__locales`, `filter__rfc5646_locales`, `sort__field`, `sort__direction`

class HomeIndexForm
  
  attr_reader :params, :cookies, :vars
  
  def initialize(params, cookies)
    @params, @cookies, @vars = params, cookies, {}

    # common
    set_pagination_variables
    set_filter__status
    set_filter__rfc5646_locales
    set_sort__field
    set_sort__direction

    # commit specific
    set_commits_filter__sha
    set_commits_filter__project_id
    set_commits_filter__hide_exported
    set_commits_filter__hide_autoimported
    set_commits_filter__show_only_mine

    # article specific
    set_articles_filter__name
    set_articles_filter__project_id
  end

  # @param [String] key name of the form variable
  # @return [String] variable's value

  def [](key)
    vars[key]
  end

  private

  # GENERAL

  def set_pagination_variables
    vars[:page] = Integer(params[:page]) rescue 1
    vars[:offset] = (vars[:page] - 1) * HomeController::PER_PAGE
    vars[:limit]  = HomeController::PER_PAGE
  end

  def set_filter__status
    status = params[:filter__status].to_s.presence || cookies[:home_index__filter__status].to_s.presence || 'uncompleted'
    status = 'uncompleted' unless %w(uncompleted completed all).include?(status)
    vars[:filter__status] = cookies[:home_index__filter__status] = status
  end

  def set_filter__rfc5646_locales
    from_param = params.key?(:filter__rfc5646_locales) ? params[:filter__rfc5646_locales] : nil
    rfc5646_locales = from_param || cookies[:home_index__filter__rfc5646_locales] || ""
    vars[:filter__locales] = rfc5646_locales.split(',').map { |l| Locale.from_rfc5646(l) }.compact
    vars[:filter__rfc5646_locales] = vars[:filter__locales].map(&:rfc5646)
    cookies[:home_index__filter__rfc5646_locales] = vars[:filter__rfc5646_locales].join(',')
  end

  def set_sort__field
    vars[:sort__field] = cookies[:home_index__sort__field] =
        params[:sort__field].presence || cookies[:home_index__sort__field].presence
  end

  def set_sort__direction
    vars[:sort__direction] = cookies[:home_index__sort__direction] =
        params[:sort__direction].presence || cookies[:home_index__sort__direction].presence
  end

  # COMMIT SPECIFIC

  def set_commits_filter__sha
    sha = params[:commits_filter__sha].presence
    vars[:commits_filter__sha] = (sha =~ /^[0-9A-F]+$/i ? sha.downcase : nil)
  end

  def set_commits_filter__project_id
    vars[:commits_filter__project_id] = cookies[:home_index__commits_filter__project_id] =
        params[:commits_filter__project_id].to_s.presence || cookies[:home_index__commits_filter__project_id].to_s.presence || 'all'
  end

  def set_commits_filter__hide_exported
    vars[:commits_filter__hide_exported] = cookies[:home_index__commits_filter__hide_exported] =
        if params[:commits_filter__hide_exported].present?
          params[:commits_filter__hide_exported] == 'true'
        elsif cookies[:home_index__commits_filter__hide_exported].present?
          cookies[:home_index__commits_filter__hide_exported] == 'true'
        else
          false
        end
  end

  def set_commits_filter__hide_autoimported
    vars[:commits_filter__hide_autoimported] = cookies[:home_index__commits_filter__hide_autoimported] =
        if params[:commits_filter__hide_autoimported].present?
          params[:commits_filter__hide_autoimported] == 'true'
        elsif cookies[:home_index__commits_filter__hide_autoimported].present?
          cookies[:home_index__commits_filter__hide_autoimported] == 'true'
        else
          false
        end
  end

  def set_commits_filter__show_only_mine
    vars[:commits_filter__show_only_mine] = cookies[:home_index__commits_filter__show_only_mine] =
        if params[:commits_filter__show_only_mine].present?
          params[:commits_filter__show_only_mine] == 'true'
        elsif cookies[:home_index__commits_filter__show_only_mine]
          cookies[:home_index__commits_filter__show_only_mine] == 'true'
        else
          false
        end
  end

  # ARTICLE SPECIFIC

  def set_articles_filter__name
    vars[:articles_filter__name] = params[:articles_filter__name].presence
  end

  def set_articles_filter__project_id
    vars[:articles_filter__project_id] = cookies[:home_index__articles_filter__project_id] =
        params[:articles_filter__project_id].to_s.presence || cookies[:home_index__articles_filter__project_id].to_s.presence || 'all'
  end
end
