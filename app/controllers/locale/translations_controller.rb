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

# Controller for translating all of a Project's strings under a certain
# locale. The `TranslationWorkbench` JavaScript object uses this controller to
# populate its content.

class Locale::TranslationsController < ApplicationController
  include TranslationDecoration

  # The number of records to return by default.
  PER_PAGE = 50

  before_filter :authenticate_user!
  before_filter :translator_required
  before_filter :find_locale
  before_filter :find_project

  respond_to :json

  # Renders a list of Translations in a certain locale under a given Project.
  #
  # Routes
  # ------
  #
  # * `GET /locales/:locale_id/projects/:project_id/translations`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                       |
  # |:-------------|:--------------------------------------|
  # | `locale_id`  | The RFC 5646 identifier for a locale. |
  # | `project_id` | The slug of a Project.                |

  def index
    include_translated = params[:include_translated].parse_bool
    include_approved   = params[:include_approved].parse_bool
    include_new        = params[:include_new].parse_bool

    offset       = params[:offset].to_i
    limit        = PER_PAGE
    query_filter = params[:filter]
    commit_id    = params[:commit]
    locale       = @locale
    project_id   = @project.id

    filter_source = params[:filter_source]
    catch :include_nothing do
      @translations = Translation.search(load: {include: {key: [:slugs, :project]}}) do
        query_terms = []
        query_terms << "commit_ids:\"#{commit_id}\"" if commit_id.present?
        query_terms << "rfc5646_locale:\"#{locale.rfc5646}\"" if locale
        if query_filter.present?
          if filter_source == 'source'
            query_terms << "source_copy:\"#{query_filter}\""
          elsif filter_source == 'translated'
            query_terms << "copy:\"#{query_filter}\""
          end
        end
        query { string query_terms.join(' '), default_operator: 'AND' } if query_terms.present?

        sort { by :created_at, 'asc' }
        from offset
        size limit

        if include_translated && include_approved && include_new
          # include everything
          filter :term, project_id: project_id
        elsif include_translated && include_approved
          filter :and,
                 {term: {project_id: project_id}},
                 {term: {translated: 1}}
        elsif include_translated && include_new
          filter :and,
                 {term: {project_id: project_id}},
                 {or: [
                          {missing: {field: 'approved', existence: true, null_value: true}},
                          {term: {approved: 0}}]}
        elsif include_approved && include_new
          filter :and,
                 {term: {project_id: project_id}},
                 {or: [
                          {term: {approved: 1}},
                          {term: {translated: 0}}]}
        elsif include_approved
          filter :and,
                 {term: {project_id: project_id}},
                 {term: {approved: 1}}
        elsif include_new
          filter :and,
                 {term: {project_id: project_id}},
                 {or: [
                          {term: {translated: 0}},
                          {term: {approved: 0}}]}
        elsif include_translated
          filter :and,
                 {term: {project_id: project_id}},
                 {missing: {field: 'approved', existence: true, null_value: true}},
                 {term: {translated: 1}}
        else
          # include nothing
          throw :include_nothing
        end
      end
    end

    @translations ||= []

    respond_with @translations do |format|
      format.json { render json: decorate(@translations).to_json }
    end
  end

  private

  def find_locale
    if params[:locale_id]
      unless (@locale = Locale.from_rfc5646(params[:locale_id]))
        respond_to do |format|
          format.any { head :not_found }
        end
      end
    end
  end

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end
end
