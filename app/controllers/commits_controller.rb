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

# Controller where users can add Commits to be imported and translated, and view
# the status of these Commits.

class CommitsController < ApplicationController
  # @private
  COMMIT_ATTRIBUTES = [:exported, :revision, :description, :due_date, :pull_request_url, :priority]

  skip_before_filter :authenticate_user!, only: [:manifest, :localize]
  before_filter :monitor_required, except: [:show, :search, :gallery, :manifest, :localize, :issues]

  before_filter :find_project
  before_filter :require_repository_url, except: [:show, :tools, :gallery, :issues, :search, :update, :destroy]
  before_filter :find_commit, except: [:create, :manifest, :localize]
  before_filter :find_format
  before_filter :set_commit_issues_presenter, only: [:show, :issues, :tools, :gallery, :search]

  respond_to :html, :json, only: [:show, :tools, :gallery, :search, :create, :update, :destroy, :issues,
                                  :sync, :match, :clear, :recalculate, :ping_stash]

  # Renders JSON information about a Commit and its translation progress.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def show
    respond_with @commit do |format|
      format.json { render json: decorate(@commit).to_json }
    end
  end

  # Renders a list of tools that can be used for a commit
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def tools
    respond_with @commit
  end

  # Renders all screenshots for a commit and a drag + drop interface to upload screenshots
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def gallery
    respond_with @commit
  end

  # Renders information about the issues associated with the keys in this commit.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id/issues`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def issues
    respond_with @commit_issues_presenter
  end

  # Renders a table displaying all keys belonging to a commit and a search bar that
  # enables users to search the commit for specific keys
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id/search`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def search
    @locales = @project.locale_requirements.inject({}) do |hsh, (locale, required)|
      hsh[locale.rfc5646] = {
        required: required,
        targeted: true,
        finished: @commit.translations.where('approved IS NOT TRUE AND rfc5646_locale = ?', locale.rfc5646).first.nil?
      }
      hsh
    end
    @keys = CommitsSearchKeysFinder.new(params, @commit).find_keys
    @keys_presenter = CommitsSearchPresenter.new(params[:locales], current_user.translator?, @project)
  end

  # Marks a commit as needing localization. Creates a CommitCreator job to do the
  # heavy lifting of importing strings.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  #
  # Body Parameters
  # ---------------
  #
  # |          |                                                            |
  # |:---------|:-----------------------------------------------------------|
  # | `commit` | Parameterized hash of Commit fields, including `revision`. |

  def create
    revision = params[:commit][:revision].strip
    other_fields           = commit_params.stringify_keys.slice(*COMMIT_ATTRIBUTES.map(&:to_s)).except('revision')
    other_fields[:user_id] = current_user.id

    options = other_fields.symbolize_keys
    @project = Project.find(@project.id)
    @commit = @project.commit!(revision, other_fields: options)

    respond_with @commit, location: project_commit_url(@project, @commit)
  rescue Git::CommitNotFoundError
    flash[:alert] = t('controllers.commits.create.commit_not_found_error', revision: revision)
    redirect_to root_url
  rescue Project::NotLinkedToAGitRepositoryError
    flash[:alert] = t('controllers.commits.create.project_not_linked_error', revision: params[:commit][:revision].strip)
    redirect_to root_url
  rescue Timeout::Error
    Squash::Ruby.notify err, project_id: project_id, sha: sha
    flash[:alert] = t('controllers.commits.create.timeout', revision: revision)
    redirect_to root_url
  end

  # Updates Commit metadata.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/commits/:commit_id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `commit_id`  | The SHA of a Commit.   |
  #
  # Body Parameters
  # ---------------
  #
  # |          |                                      |
  # |:---------|:-------------------------------------|
  # | `commit` | Parameterized hash of Commit fields. |

  def update
    @commit.update_attributes commit_params
    flash[:success] = t('controllers.commits.update.success', sha: @commit.revision_prefix)
    respond_with @commit, location: project_commit_url(@project, @commit)
  end

  # Removes a Commit.
  #
  # Routes
  # ------
  #
  # * `DELETE /projects/:project_id/commits/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def destroy
    @commit.destroy

    Commit.tire.index.refresh

    respond_with(@commit) do |format|
      format.html { redirect_to root_url, notice: t('controllers.commits.destroy.deleted', sha: @commit.revision_prefix) }
    end
  end

  # Re-scans a revision for strings and adds new Translation records as
  # necessary.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/sync`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def sync
    @commit.import_batch.jobs do
      CommitImporter.perform_once @commit.id
    end
    respond_with @commit, location: nil
  end

  # Recalculates the readiness of a commit.  This method should be used
  # to fix commits that are "red" but should be "green"
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/recalculate`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def recalculate
    @commit.recalculate_ready!
    flash[:success] = t('controllers.commits.recalculate.success', sha: @commit.revision_prefix)
    respond_with @commit, location: project_commit_url(@project, @commit)
  end

  # Recalculates the readiness of a commit.  This method should be used
  # to fix commits that are "red" but should be "green"
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/recalculate`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def ping_stash
    StashWebhookPinger.new.perform(@commit.id)
    flash[:success] = t('controllers.commits.stash.success', sha: @commit.revision_prefix)
    respond_with @commit, location: project_commit_url(@project, @commit)
  end

  # Renders a digest of all translated strings applying to a revision. The
  # request format is used to determine in what format the output will be
  # rendered.
  #
  # The response will be a 404 Not Found if the Commit is not yet fully
  # localized and approved, unless the `partial` query parameter is set.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id/manifest`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |
  #
  # Query Parameters
  #
  # |           |                                                                               |
  # |:----------|:------------------------------------------------------------------------------|
  # | `locale`  | The RFC 5646 identifier for a locale.                                         |
  # | `partial` | If `true`, partially-translated manifests are allowed.                        |
  #
  # Responses
  # ---------
  #
  # ### Commit is not fully localized
  #
  # 404 Not Found is returned with no body.

  def manifest
    @commit = @project.commit!(params[:id], skip_create: true)

    compiler = Compiler.new(@commit)
    file     = compiler.manifest(request.format,
                                 locale:  params[:locale].presence,
                                 partial: params[:partial].parse_bool)

    response.charset                   = file.encoding
    response.headers['X-Git-Revision'] = @commit.revision
    send_data file.content,
              filename: file.filename,
              type:     file.mime_type
    file.close

  rescue Compiler::CommitLoadingError
    render text: 'Commit still loading', status: :not_found
  rescue Compiler::CommitNotReadyError
    render text: 'Commit not ready', status: :not_found
  rescue Compiler::UnknownLocaleError
    render text: 'Unknown locale', status: :bad_request
  rescue Compiler::UnknownExporterError
    render text: 'Unknown format', status: :not_acceptable
  rescue Git::CommitNotFoundError => err
    render text: t("controllers.commits.base.not_found_in_repo", revision: params[:id]), status: :not_found
  rescue Exporter::NoLocaleProvidedError
    render text: 'Must provide a single locale', status: :bad_request
  end

  # Generates a tarball of localized files, extractable into the project root.
  # Localized files are generated by subclasses of {Localizer::Base}. The Commit
  # should have Translations imported by an importer that has a corresponding
  # localizer.
  #
  # The response will be a 404 Not Found if the Commit is not yet fully
  # localized and approved, unless the `partial` query parameter is set.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:id/localize`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |
  #
  # Query Parameters
  #
  # |           |                                                                                           |
  # |:----------|:------------------------------------------------------------------------------------------|
  # | `locale`  | The RFC 5646 identifier for a locale. If not provided, all required locales are included. |
  # | `partial` | If `true`, partially-translated manifests are allowed.                                    |
  #
  # Responses
  # ---------
  #
  # ### Commit is not fully localized
  #
  # 404 Not Found is returned with no body.

  def localize
    @commit = @project.commit!(params[:id], skip_create: true)

    compiler = Compiler.new(@commit)
    file     = compiler.localize(locale:  params[:locale].presence,
                                 partial: params[:partial].parse_bool)

    respond_to do |format|
      format.gz do
        send_data file.content, filename: file.filename, type: file.mime_type
      end
      format.any { head :not_acceptable } #TODO why is this necessary?
    end

    file.close

  rescue Compiler::CommitLoadingError
    render text: 'Commit still loading', status: :not_found
  rescue Compiler::CommitNotReadyError
    render text: 'Commit not ready', status: :not_found
  rescue Compiler::UnknownLocaleError
    render text: 'Unknown locale', status: :bad_request
  rescue Git::CommitNotFoundError => err
    render text: t("controllers.commits.base.not_found_in_repo", revision: params[:id]), status: :not_found
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end

  def find_commit
    if params[:id] == 'latest'
      if (latest_commit = @project.latest_commit)
        return redirect_to params.merge(id: latest_commit, only_path: true)
      else
        raise ActiveRecord::RecordNotFound, "No latest commit for project"
      end
    end
    @commit = @project.commits.for_revision(params[:id]).first!
  end

  def require_repository_url
    render json: { alert: t('controllers.commits.blank_repository_url') } unless @project.git?
  end

  def find_format
    @format = @project.default_manifest_format
  end

  def decorate(commit)
    commit.as_json.merge(
        url:                project_commit_url(@project, commit),
        import_url:         import_project_commit_url(@project, commit),
        sync_url:           sync_project_commit_url(@project, commit, format: 'json'),
        percent_done:       commit.fraction_done.nan? ? 0.0 : commit.fraction_done*100,
        translations_done:  commit.translations_done,
        translations_total: commit.translations_total,
        strings_total:      commit.strings_total
    )
  end

  def commit_params
    params[:commit]["due_date"] = DateTime::strptime(params[:commit]["due_date"], "%m/%d/%Y") rescue ''
    params.require(:commit).permit(*COMMIT_ATTRIBUTES)
  end

  def set_commit_issues_presenter
    @commit_issues_presenter ||= ArticleOrCommitIssuesPresenter.new(@commit)
  end
end
