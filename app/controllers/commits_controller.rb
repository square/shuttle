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

  before_filter :authenticate_user!, except: [:manifest, :localize]
  before_filter :monitor_required, except: [:manifest, :localize]
  before_filter :monitor_required, only: :destroy
  before_filter :find_project
  before_filter :find_commit, except: [:create, :manifest, :localize]

  respond_to :html, :json, only: [:show, :create, :update, :destroy, :import, :sync, :match, :redo]

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
      format.html do
        @locales = @project.locale_requirements.inject({}) do |hsh, (locale, required)|
          hsh[locale.rfc5646] = {
              required: required,
              targeted: true,
              finished: @commit.translations.where('approved IS NOT TRUE AND rfc5646_locale = ?', locale.rfc5646).first.nil?
          }
          hsh
        end
      end
    end
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

    respond_to do |format|
      format.json do
        other_fields           = params[:commit].stringify_keys.slice(*COMMIT_ATTRIBUTES.map(&:to_s)).except('revision')
        other_fields[:user_id] = current_user.id

        if already_submitted_revision?(@project, revision)
          render json: {alert: t('controllers.commits.create.already_submitted')}
        else
          CommitCreator.perform_once @project.id, revision, other_fields: other_fields
          record_submitted_revision @project, revision
          render json: {success: t('controllers.commits.create.success', revision: revision)}
        end
      end
    end
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
    if !params[:commit]["due_date"].nil?
      params[:commit]["due_date"] = Date::strptime(params[:commit]["due_date"], "%m/%d/%Y")
    end
    @commit.update_attributes commit_params
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
      format.html { redirect_to root_url, notice: t('controllers.commits.destroy.deleted', sha: @commit.revision[0, 6]) }
    end
  end

  # Scans a revision of the code for already-localized strings in a given
  # locale and adds them to the database as approved Translation objects.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/import`
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
  # |          |                                       |
  # |:---------|:--------------------------------------|
  # | `locale` | The RFC 5646 identifier for a locale. |

  def import
    CommitImporter.perform_once @commit.id, locale: params[:locale]
    respond_with @commit, location: nil
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
    CommitImporter.perform_once @commit.id
    respond_with @commit, location: nil
  end

  # Re-scans a revision for strings and adds new Translation records as
  # necessary. Unlike {#sync}, this method rescans blobs that have already been
  # scanned.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/redo`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `id`         | The SHA of a Commit.   |

  def redo
    CommitImporter.perform_once @commit.id
    respond_with @commit, location: nil
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
  # | `force`   | If `true`, forces a recompile of the manifest even if there is a cached copy. |
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
                                 partial: params[:partial].parse_bool,
                                 force:   params[:force].parse_bool)

    response.charset                   = file.encoding
    response.headers['X-Git-Revision'] = @commit.revision
    send_data extract_data(file),
              filename: file.filename,
              type:     file.mime_type
    file.close

  rescue Compiler::CommitNotReadyError
    render text: 'Commit not ready', status: :not_found
  rescue Compiler::UnknownLocaleError
    render text: 'Unknown locale', status: :bad_request
  rescue Compiler::UnknownExporterError
    render text: 'Unknown format', status: :not_acceptable
  rescue ActiveRecord::RecordNotFound
    render text: 'Unknown commit', status: :not_found
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
  # | `force`   | If `true`, forces a recompile of the tarball even if there is a cached copy.              |
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
                                 partial: params[:partial].parse_bool,
                                 force:   params[:force].parse_bool)

    respond_to do |format|
      format.gz do
        send_data extract_data(file), filename: file.filename, type: file.mime_type
      end
      format.any { head :not_acceptable } #TODO why is this necessary?
    end

    file.close

  rescue Compiler::CommitNotReadyError
    render text: 'Commit not ready', status: :not_found
  rescue Compiler::UnknownLocaleError
    render text: 'Unknown locale', status: :bad_request
  rescue ActiveRecord::RecordNotFound
    render text: 'Unknown commit', status: :not_found
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

  def decorate(commit)
    commit.as_json.merge(
        url:                project_commit_url(@project, commit),
        import_url:         import_project_commit_url(@project, commit),
        sync_url:           sync_project_commit_url(@project, commit, format: 'json'),
        redo_url:           redo_project_commit_url(@project, commit, format: 'json'),
        percent_done:       commit.fraction_done.nan? ? 0.0 : commit.fraction_done*100,
        translations_done:  commit.translations_done,
        translations_total: commit.translations_total,
        strings_total:      commit.strings_total
    )
  end

  # extract data while preserving BOM from a Compiler::File object
  def extract_data(file)
    if file.io.respond_to?(:string)
      str = file.io.string
    else
      str = file.io.read
    end
    return str.force_encoding(file.encoding) if file.encoding
    str
  end

  def commit_params
    params.require(:commit).permit(*COMMIT_ATTRIBUTES)
  end

  def already_submitted_revision?(project, revision)
    Shuttle::Redis.get(submitted_revision_key(project, revision)) == '1'
  end

  def record_submitted_revision(project, revision)
    Shuttle::Redis.set submitted_revision_key(project, revision), '1'
    Shuttle::Redis.expire submitted_revision_key(project, revision), 30
  end

  def submitted_revision_key(project, revision)
    "submitted_revision:#{project.id}:#{revision}"
  end
end
