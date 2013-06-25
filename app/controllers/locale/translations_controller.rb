# Copyright 2013 Square Inc.
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
# locale. The `TranslationPanel` JavaScript object uses this controller to
# populate its content.

class Locale::TranslationsController < ApplicationController
  include TranslationDecoration

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

    @translations = if params[:commit].present?
                      @commit = Commit.find(params[:commit])
                      @commit.translations
                    else
                      @project.translations
                    end

    @translations = @translations.in_locale(@locale).
        order('translations.created_at DESC').offset(params[:offset].to_i).limit(50).
        includes(key: :project)
    if include_translated && include_approved && include_new
      # include everything
    elsif include_translated && include_approved
      @translations = @translations.where(translated: true)
    elsif include_translated && include_new
      @translations = @translations.where('approved IS NULL OR approved IS FALSE')
    elsif include_approved && include_new
      @translations = @translations.where('approved IS TRUE OR translated IS FALSE')
    elsif include_approved
      @translations = @translations.where('approved IS TRUE')
    elsif include_new
      @translations = @translations.where('translated IS FALSE OR approved IS FALSE')
    elsif include_translated
      @translations = @translations.where(translated: true, approved: nil)
    else
      # include nothing
      @translations = @translations.where('FALSE')
    end

    if params[:filter].present?
      if params[:filter_source] == 'source'
        tsc = SearchableField::text_search_configuration(@project.base_locale)
        @translations = @translations.source_copy_query(params[:filter], tsc)
      elsif params[:filter_source] == 'translated'
        tsc = SearchableField::text_search_configuration(@locale)
        @translations = @translations.copy_query(params[:filter], tsc)
      end
    end

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
