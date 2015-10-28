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

# Controller for working with {Project Projects} in the context of a specific
# locale.

class Locale::ProjectsController < ApplicationController

  before_filter :translator_required
  before_filter :locale_access_required
  before_filter :find_locale
  before_filter :find_project, only: :show

  respond_to :html, only: :show
  respond_to :json, only: :index

  # Returns a list of Projects whose required locales include `locale`.
  #
  # Routes
  # ------
  #
  # * `GET /locales/:locale_id/projects.json`
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                 |
  # |:------------|:--------------------------------|
  # | `locale_id` | The RFC 5646 code for a locale. |

  def index
    respond_with(@projects = Project.scoped.to_a.select { |p| p.targeted_rfc5646_locales.include? @locale.rfc5646 }) do |format|
      format.json { render json: decorate(@projects).to_json }
    end
  end

  # Displays a web page where a translator can view and edit the translations
  # for a project in a `locale`.
  #
  # Routes
  # ------
  #
  # * `GET /locales/:locale_id/projects/:id
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                 |
  # |:------------|:--------------------------------|
  # | `locale_id` | The RFC 5646 code for a locale. |
  # | `id`        | The slug of a {Project}.        |

  def show
    translations_form = LocaleProjectsShowForm.new(params)
    translations_finder = LocaleProjectsShowFinder.new(translations_form)
    @translations = translations_finder.find_translations
    @glossary_entries = LocaleGlossaryEntry.includes(:source_glossary_entry).joins(:source_glossary_entry)
        .where(
            source_glossary_entries: {source_rfc5646_locale: Shuttle::Configuration.locales.source_locale},
            rfc5646_locale:          @locale.rfc5646,
            approved:                true)
        .map(&:as_translation_json)
        .compact
    @presenter = LocaleProjectsShowPresenter.new(@project, translations_form)
    respond_with @project
  end

  private

  def find_locale
    @locale = Locale.from_rfc5646(params[:locale_id])
    unless @locale
      respond_to do |format|
        format.any { head :not_found }
      end
    end
  end

  def find_project
    @project = Project.find_from_slug!(params[:id])
  end

  def decorate(projects)
    projects.map do |project|
      project.as_json.merge(
          url:                       locale_project_url(@locale.rfc5646, project),
          pending_translation_count: project.pending_translations(@locale),
          pending_review_count:      project.pending_reviews(@locale)
      )
    end
  end

  def locale_access_required
    if current_user.has_access_to_locale?(params[:locale_id])
      true
    else
      respond_to do |format|
        format.html { redirect_to root_url, alert: t('controllers.locale.projects.locale_access_required') }
        format.any { head :forbidden }
      end
      false
    end
  end
end
