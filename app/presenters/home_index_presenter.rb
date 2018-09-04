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

class HomeIndexPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TextHelper

  attr_reader :locales, :stats
  delegate :item_stat, to: :stats

  def initialize(commits, articles, groups, assets, locales)
    @locales = locales
    @stats = ArticleAndCommitNotApprovedTranslationStats.new(commits, articles, groups, assets, locales)
  end

  # @param [Commit, Article] item The {Commit} or {Article} for which full description will be returned.
  # @return [String] item's full description.

  def full_description(item)
    (sanitize item.description, tags: []) || '-'
  end

  # @param [Commit, Article] item The {Commit} or {Article} for which short description will be returned.
  # @return [String] item's short description.

  def short_description(item)
    full_desc = full_description(item)
    if full_desc.start_with?("Automatically imported from ")
      full_desc
    else
      truncate(full_desc, length: 50)
    end
  end

  # For a Commit, this will be the author info, for an Article, it will be blank for now.
  #
  # @param [Commit, Article, Asset] item The {Commit}, {Article}, or {Asset} for which sub description will be returned.
  # @return [String] item's short description.

  def sub_description(item)
    item.is_a?(Commit) ? "Authored By: #{item.author}" : ""
  end

  # @param [Commit, Article] item The {Commit}, {Article}, or {Asset} for which translate link path will be returned.
  # @return [String] the path for the translate link

  def translate_link_path(user, item)
    approved_locales = user.admin? ? item.required_locales : user.approved_locales
    selected_locales = locales.presence || item.required_locales
    rfc5646_locale = ((approved_locales & selected_locales).presence || approved_locales).first.rfc5646
    item_specific_path_params = nil
    if item.is_a?(Commit)
      item_specific_path_params = { commit: item.revision }
    elsif item.is_a?(Article)
      item_specific_path_params = { article_id: item.id }
    elsif item.is_a?(Asset)
      item_specific_path_params = { asset_id: item.id }
    elsif item.is_a?(Group)
      item_specific_path_params = { group: item.to_param }
    end
    locale_project_path({ locale_id: rfc5646_locale, id: item.project.to_param }.merge(item_specific_path_params) )
  end

  # @param [Commit, Article] item The {Commit}, {Article}, {Group} or {Asset} that will be updated.
  # @return [String] the path to post to to update a Commit/Article

  def update_item_path(item)
    if item.is_a?(Commit)
      project_commit_path(item.project, item, format: 'json')
    elsif item.is_a?(Article)
      api_v1_project_article_path(project_id: item.project.id, name: item.name, format: 'json')
    elsif item.is_a?(Group)
      api_v1_project_group_path(project_id: item.project.id, name: item.name, format: 'json')
    elsif item.is_a?(Asset)
      project_asset_path(item.project, item, format: 'json')
    end
  end
end
