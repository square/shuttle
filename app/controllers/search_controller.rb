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

class SearchController < ApplicationController


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
          @results = SearchKeysFinder.new(current_user, params).find_keys
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

        @results = SearchCommitsFinder.new(params).find_commits
        render json: decorate_commits(@results).to_json
      end
    end
  end

  def issues
    user_name_param = params[:user_name].try(:downcase)

    if user_name_param
      names = user_name_param.split(' ')
      user_ids = User.where("lower(first_name) LIKE ? OR lower(last_name) LIKE ?", "%#{names.first}%", "%#{names.last}%").pluck(:id)
      @issues = Issue.where("user_id IN (?) OR updater_id IN (?)", user_ids, user_ids).page(params[:page])
    else
      @issues = Issue.includes(:user, :updater, translation: {key: :project}).page(params[:page])
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
      translations = if current_user.approved_locales.empty?
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
