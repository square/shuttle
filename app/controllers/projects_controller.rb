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

# Controller for working with {Project Projects}.

class ProjectsController < ApplicationController
  skip_before_filter :authenticate_user!, only: [:stash_webhook]
  skip_before_action :verify_authenticity_token, only: [:stash_webhook]

  before_filter :monitor_or_reviewer_required, only: [:new, :create, :edit, :update]
  before_filter :admin_required, only: [:setup_mass_copy_translations, :mass_copy_translations]
  before_filter :find_project, except: [:index, :new, :create]

  before_filter(only: [:create, :update]) do
    fix_empty_arrays [:project, :key_exclusions],
                     [:project, :key_inclusions],
                     [:project, :skip_paths],
                     [:project, :only_paths],
                     [:project, :watched_branches],
                     [:project, :required_rfc5646_locales],
                     [:project, :other_rfc5646_locales]
    fix_empty_hashes [:project, :key_locale_exclusions],
                     [:project, :key_locale_inclusions],
                     [:project, :only_importer_paths],
                     [:project, :skip_importer_paths],
                     reject_blank_value_elements: true
    # fix_empty_hashes [:project, :targeted_rfc5646_locales],
    #                  map_values: ->(req) { req.parse_bool }
  end

  respond_to :html, except: :show
  respond_to :json, only: :show

  # Returns a list of Projects.
  #
  # Routes
  # ------
  #
  # * `GET /projects`

  def index
    @projects = Project.order('LOWER(name)')
    respond_with(@projects) do |format|
      format.json do
        if params[:offset].to_i > 0
          @projects = @projects.offset(params[:offset].to_i)
        end
        render json: decorate(@projects).to_json
      end
    end
  end

  # Returns information about a Project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |

  def show
    respond_with @project do |format|
      format.json do
        render json: @project.as_json.merge(
                         commits_url: project_commits_url(@project, format: 'json'),
                         commits:     @project.commits.order('committed_at DESC').limit(10).map { |commit|
                           commit.as_json.merge(
                               percent_done:       commit.fraction_done.nan? ? 0.0 : commit.fraction_done*100,
                               translations_done:  commit.translations_done,
                               translations_total: commit.translations_total,
                               strings_total:      commit.strings_total,
                               import_url:         import_project_commit_url(@project, commit, format: 'json'),
                               sync_url:           sync_project_commit_url(@project, commit, format: 'json'),
                               url:                project_commit_url(@project, commit),
                               status_url:         project_commit_url(@project, commit),
                           )
                         }
                     )
      end
    end
  end

  # Displays a form where an admin can add a new Project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/new`

  def new
    @project ||= Project.new
    # Default targeted_rfc5646_locales to display to user.
    @project.targeted_rfc5646_locales = {@project.base_rfc5646_locale => true}
    respond_with @project
  end

  # Creates a new Project.
  #
  # Routes
  # ------
  #
  # * `POST /projects`
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                            |
  # |:----------|--------------------------------------------|
  # | `project` | Parameterized hash of Project information. |

  def create
    @project = Project.create(project_params)
    if @project.errors.blank?
      flash[:success] = t('controllers.projects.create.success', project: @project.name)
    else
      flash.now[:alert] = @project.errors.full_messages.unshift(t('controllers.projects.create.failure'))
    end
    respond_with @project, location: projects_url
  end

  # Displays a form where an admin can edit a Project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |

  def edit
    respond_with @project
  end

  # Updates a Project with new information.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                            |
  # |:----------|--------------------------------------------|
  # | `project` | Parameterized hash of Project information. |

  def update
    @project.update_attributes project_params
    if @project.errors.blank?
      flash[:success] = t('controllers.projects.update.success', project: @project.name)
    else
      flash.now[:alert] = @project.errors.full_messages.unshift(t('controllers.projects.update.failure'))
    end
    respond_with @project, location: edit_project_url(@project)
  end

  # Receives a github webhook and triggers a new import for the latest commit.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:id/github-pull-request-builder`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                                          |
  # |:----------|----------------------------------------------------------|
  # | `payload` | See: https://help.github.com/articles/post-receive-hooks |

  def github_webhook
    payload = JSON.parse(params[:payload])
    requested_branch = payload['ref'].split('/').last
    branch_is_valid = @project.git? && @project.watched_branches.include?(requested_branch)
    if branch_is_valid
      revision = payload['after']
      other_fields = { description: 'github webhook', user_id: current_user.id }
      CommitCreator.perform_once @project.id, revision, other_fields: other_fields
    end
    respond_to do |format|
      format.json do
        render status: :ok, json: { success: branch_is_valid }
      end
    end
  end

  # Receives a stash webhook and triggers a new import for the latest commit,
  # if project has a repository_url. Otherwise, it returns a 400 error.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:id/stash-pull-request-builder`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |           |                                                          |
  # |:----------|----------------------------------------------------------|
  # | `ref`     | The ref of the SHA that needs to be built                |
  # | `sha`     | The SHA of the commit that should be built               |
  # | `type`    | Whether it was a pull request or push that triggered it  |

  def stash_webhook
    if @project.git?
      revision = params[:sha]
      other_fields = { description: 'Requested due to a Pull Request on Stash.' }
      CommitCreator.perform_once @project.id, revision, other_fields: other_fields
      render status: :ok, text: 'Success'
    else
      render status: :bad_request, text: 'Repository url is blank'
    end
  end

  # Shows a page were admins can configure settings to mass copy translations from one locale to another.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:id/mass_copy_translations`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |

  def setup_mass_copy_translations
  end

  # Kicks off a job which will mass copy translations from one locale to another.
  # It only copies from translations which are already approved.
  # It only copies into translations which are not yet translated.
  # It preserves the approved state.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:id/mass_copy_translations`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                   |
  # |:-----|:------------------|
  # | `id` | A Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |                       |                                                          |
  # |:----------------------|----------------------------------------------------------|
  # | `from_rfc5646_locale` | The ref of the SHA that needs to be built                |
  # | `to_rfc5646_locale`   | The SHA of the commit that should be built               |

  def mass_copy_translations
    errors = ProjectTranslationsMassCopier.find_locale_errors(@project, params[:from_rfc5646_locale], params[:to_rfc5646_locale])

    if errors.blank?
      ProjectTranslationsMassCopier.perform_once(@project.id, params[:from_rfc5646_locale], params[:to_rfc5646_locale])
      flash[:success] = t('controllers.projects.mass_copy_translations.success',
                          from: params[:from_rfc5646_locale], to: params[:to_rfc5646_locale])
      redirect_to setup_mass_copy_translations_project_url(@project)
    else
      flash.now[:alert] = [t('controllers.projects.mass_copy_translations.failure')] + errors
      render 'setup_mass_copy_translations'
    end
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:id])
  end

  def decorate(projects)
    projects.map do |project|
      project.as_json.merge(
          url:         project_url(project),
          commits_url: project_commits_url(project, format: 'json'),
          edit_url:    edit_project_url(project)
      )
    end
  end

  def project_params
    # too hard to do this with strong parameters :(
    if current_user.try!(:admin?)
      # Only admins can change required locales
      targeted_rfc5646_locales = Hash[params[:project][:required_rfc5646_locales].map {|locale| [locale, true]}]
      targeted_rfc5646_locales = targeted_rfc5646_locales.merge(
        Hash[params[:project][:other_rfc5646_locales].map {|locale| [locale, false]}]
      )
    elsif @project
      # Other roles are forced to maintain the same required locales.
      targeted_rfc5646_locales = @project.targeted_rfc5646_locales
    else
      # Set required locales to just base locale
      base_rfc5646_locale = Project.columns_hash['base_rfc5646_locale'].default
      targeted_rfc5646_locales = {base_rfc5646_locale => true}
    end

    params[:project][:skip_imports] = Importer::Base.implementations.map(&:ident) - params[:project][:use_imports]

    if params[:project][:use_key_exclusions]
      params[:project][:key_inclusions] = []
    else
      params[:project][:key_exclusions] = []
    end

    if params[:project][:use_skip_paths]
      params[:project][:only_paths] = []
    else
      params[:project][:skip_paths] = []
    end

    project_params = params[:project].to_hash.slice(*%w(
        name repository_url base_rfc5646_locale due_date
        github_webhook_url stash_webhook_url skip_imports default_manifest_format key_exclusions
        key_inclusions skip_paths only_paths
        watched_branches touchdown_branch
        manifest_directory manifest_filename
        key_locale_exclusions key_locale_inclusions
        only_importer_paths skip_importer_paths
        disable_locale_association_checkbox_settings
    ))
    project_params["targeted_rfc5646_locales"] = targeted_rfc5646_locales
    project_params
  end
end
