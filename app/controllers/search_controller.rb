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

class SearchController < ApplicationController
  # The number of records to return by default.
  PER_PAGE = 50

  def translations
    @presenter = TranslationsSearchPresenter.new(current_user.translator?)
    form  = SearchTranslationsForm.new(params)
    if form[:target_locales].present?
      return head(:unprocessable_entity) unless form[:target_locales].all?
    end
    translations_finder = SearchTranslationsFinder.new(form)
    @results = translations_finder.find_translations
  end



  def keys
    respond_to do |format|
      format.html # keys.html.erb
      format.json do
        return head(:unprocessable_entity) if params[:project_id].to_i <= 0

        if params[:metadata] # return metadata about the search only
          @project = Project.find(params[:project_id])
          render json: {
                           locales: ([@project.base_locale] + @project.targeted_locales.sort_by(&:rfc5646)).uniq
                       }.to_json
        else
          query_filter = params[:filter]
          status       = params[:status]
          offset       = params[:offset].to_i
          id           = params[:project_id]
          limit        = params.fetch(:limit, PER_PAGE)
          not_elastic  = params[:not_elastic_search] 

          @results = Key.search(load: {include: [:translations, :project]}) do
            if query_filter.present?
              if not_elastic
                filter :term, original_key_exact: query_filter
              else
                query { match 'original_key', query_filter, operator: 'and' }
              end
            else
              sort { by :original_key, 'asc' }
            end
            filter :term, project_id: id

            unless status.blank?
              filter :term, ready: status
            end

            from offset
            size limit
          end
          render json: decorate_keys(@results).to_json
        end
      end
    end
  end

  def commits
    respond_to do |format|
      format.html
      format.json do
        return head(:unprocessable_entity) if params[:project_id].to_i < 0

        sha = params[:sha]
        project_id = params[:project_id].to_i
        limit = params.fetch(:limit, 50)

        @results = Commit.search(load: {include: :project}) do
          filter :prefix, revision: sha if sha
          filter :term, project_id: project_id if project_id > 0
          size limit
          sort { by :created_at, 'desc' }
        end

        render json: decorate_commits(@results).to_json
      end
    end
  end

  private

  def decorate_translations(translations)
    translations.map do |translation|
      translation.as_json.merge(
          locale:        translation.locale.as_json,
          source_locale: translation.source_locale.as_json,
          url:           (
                         if current_user.translator?
                           edit_project_key_translation_url(translation.key.project, translation.key, translation)
                         else
                           project_key_translation_url(translation.key.project, translation.key, translation)
                         end),
          project:       translation.key.project.as_json,
          key:           translation.key.key
      )
    end
  end

  def decorate_keys(keys)
    keys.map do |key|
      translations = if current_user.approved_locales.empty? then
                       key.translations
                     else
                       key.translations.select { |t| current_user.approved_locales.include?(t.locale) }
                     end
      key.as_json.merge(
          translations: translations.map do |translation|
            translation.as_json.merge(
                url: if current_user.translator?
                       edit_project_key_translation_url(translation.key.project, translation.key, translation)
                     else
                       project_key_translation_url(translation.key.project, translation.key, translation)
                     end
            )
          end
      )
    end
  end

  def decorate_commits(commits)
    commits.map do |commit|
      commit.as_json.merge(
          url:     project_commit_url(commit.project, commit),
          project: commit.project
      )
    end
  end
end
