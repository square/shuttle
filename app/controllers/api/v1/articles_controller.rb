# Copyright 2015 Square Inc.
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

# This api can be consumed by external applications or internal views to
# allow users to create/update/view Articles.
#
# If there is an `api_token`, the request will be authenticated via that token;
# otherwise, it will be authenticated via session using the `authenticate_user!`
# method that's used everywhere else in the application.

module Api
  module V1
    class ArticlesController < ApplicationController
      respond_to :json, only: [:create, :show, :update, :manifest, :issues, :index]
      respond_to :html, only: [:create, :show, :update, :manifest, :issues, :new, :edit]

      skip_before_filter :authenticate_user!,        if: :api_request?
      skip_before_action :verify_authenticity_token, if: :api_request?
      before_filter :authenticate_with_api_token!,   if: :api_request?

      before_filter :find_project
      before_filter :find_article, only: [:show, :edit, :update, :manifest, :issues]
      before_filter :set_article_issues_presenter, only: [:show, :issues]

      # EXTERNAL ONLY
      #
      # Returns all Articles in the Project.
      #
      # Since Articles are displayed on the dashboard internally, this endpoint is only
      # for external API requests.
      #
      # Routes
      # ------
      #
      # * `/api/v1/projects/:project_id/articles(.format)?api_token=:api_token`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                              |
      # |:-------------|:-----------------------------|
      # | `project_id` | The id of a Project.         |
      # | `api_token`  | The api token for a Project. |

      def index
        respond_with @project.articles do |format|
          format.json { render json: decorate_articles(@project.articles) }
        end
      end

      # INTERNAL ONLY
      #
      # Used only internally to show a new html form to create an Article.
      #
      # Routes
      # ------
      #
      # * `/api/v1/projects/:project_id/articles/new`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                              |
      # |:-------------|:-----------------------------|
      # | `project_id` | The id of a Project.         |

      def new
        @article = @project.articles.build
        respond_with @article
      end

      # Creates an Article in a Project.
      #
      # Routes
      # ------
      #
      # * `POST /api/v1/projects/:project_id/articles(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      #
      # Body Parameters
      # ---------------
      #
      # |                            |                                                                                                               |
      # |:---------------------------|:--------------------------------------------------------------------------------------------------------------|
      # | `name`                     | The name of the Article.                                                                                      |
      # | `description`              | The description of the Article                                                                                |
      # | `sections_hash`            | A hash mapping Section names to Section source copies { 'title' => '<p>hello</p>', 'body' => '<p>world</p>' } |
      # | `email`                    | An email address which can be used for communication regarding the Article .                                  |
      # | `base_rfc5646_locale`      | Base rfc5646 locale of the Article. Ex: 'en'                                                                  |
      # | `targeted_rfc5646_locales` | Targeted rfc5646 locales for the Article. Ex: { 'fr' => true, 'es-US' => false }                              |
      # | `priority`                 | Priority for translation. Potential values: 0 (higher priority) to 3, nil.                                    |
      # | `due_date`                 | Due date for translation. Format: '%m/%d/%Y', Ex: '01/17/2015'                                                |


      def create
        @article = @project.articles.create(params_for_create)

        if @article.errors.blank?
          flash[:success] = 'Article is successfuly created!'
        else
          flash.now[:alert] = ['Article could not be created:'] + @article.errors.full_messages
        end

        respond_with @article, location: (api_v1_project_article_url(@project.id, @article.name) if @article.persisted? ) do |format|
          format.json do
            if @article.errors.blank?
              render json: decorate_article(@article)
            else
              render json: { error: { errors: @article.errors } }, status: :bad_request
            end
          end
        end
      end

      # Returns an Article.
      #
      # Routes
      # ------
      #
      # * `GET /api/v1/projects/:project_id/articles/:name(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      # | `name`       | The `name` of the Article.                                                              |

      def show
        respond_with @article do |format|
          format.json do
            render json: decorate_article(@article)
          end
        end
      end

      # INTERNAL ONLY
      #
      # Used only internally to show an html form to edit an Article.
      #
      # Routes
      # ------
      #
      # * `/api/v1/projects/:project_id/articles/:name/edit`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                              |
      # |:-------------|:-----------------------------|
      # | `project_id` | The id of a Project.         |
      # | `name`       | The `name` of the Article.   |

      def edit
        respond_with @article
      end

      # Updates a Article in a Project.
      #
      # Doesn't allow an update if there is a pending import or an import is in progress and the update
      # attempts to change a sensitive attribute that would trigger a re-import
      #
      # Routes
      # ------
      #
      # * `PATCH /api/v1/projects/:project_id/articles/:name(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      # | `name`       | The `name` of the Article.                                                              |
      #
      # Body Parameters
      # ---------------
      #
      # |                            |                                                                                                               |
      # |:---------------------------|:--------------------------------------------------------------------------------------------------------------|
      # | `name`                     | The new name of the Article (ie. update the name via this field.)                                             |
      # | `description`              | The description of the Article                                                                                |
      # | `sections_hash`            | A hash mapping Section names to Section source copies { 'title' => '<p>hello</p>', 'body' => '<p>world</p>' } |
      # | `email`                    | An email address which can be used for communication regarding the Article .                                  |
      # | `targeted_rfc5646_locales` | Targeted rfc5646 locales for the Article. Ex: { 'fr' => true, 'es-US' => false }                              |
      # | `priority`                 | Priority for translation. Potential values: 0 (higher priority) to 3, nil.                                    |
      # | `due_date`                 | Due date for translation. Format: '%m/%d/%Y', Ex: '01/17/2015'                                                |

      def update
        _params_for_update = params_for_update # cache
        if @article.loading? && Article::FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED.any? do |field|
                    # if there is a pending import or an import is in progress, and an import triggering field is trying to be changed
                    _params_for_update.key?(field) && (_params_for_update[field] != @article.send(field.to_sym))
                  end
          @article.errors.add(:base, :not_finished)
        else
          @article.update(_params_for_update)
        end

        respond_with @article do |format|
          format.html do
            if @article.errors.blank?
              flash[:success] = 'Article is successfuly created!'
              redirect_to api_v1_project_article_url(@project.id, @article.name)
            else
              flash.now[:alert] = ['Article could not be updated:'] + @article.errors.full_messages
              render 'api/v1/articles/edit'
            end
          end

          format.json do
            if @article.errors.blank?
              render json: decorate_article(@article)
            else
              render json: { error: { errors: @article.errors } }, status: :bad_request
            end
          end
        end
      end

      # Returns the translated copies of a Article if all translations are finished.
      # Returns the error message, otherwise.
      #
      # Routes
      # ------
      #
      # * `GET /api/v1/projects/:project_id/articles/:name/manifest(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      # | `name`       | The `name` of the Article.                                                              |

      def manifest
        begin
          @manifest = Exporter::Article.new(@article).export
        rescue Exporter::Article::Error => @error
        end

        respond_with @article do |format|
          format.json do
            if @manifest
              render json: @manifest
            else
              render json: { error: { errors: [{ message: @error.inspect }] } }, status: :bad_request
            end
          end
        end
      end

      # Returns the active issues of an Article.
      #
      # Routes
      # ------
      #
      # * `GET /api/v1/projects/:project_id/articles/:name/routes(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      # | `name`       | The `name` of the Article.                                                              |

      def issues
        respond_with @article_issues_presenter do |format|
          format.json { render json: @article_issues_presenter.as_json(only: [:priority, :kind, :status, :summary, :description, :subscribed_emails]) }
        end
      end

      private

      # ===== START AUTHENTICATION/AUTHORIZATION/VALIDATION ============================================================
      def authenticate_with_api_token!
        unless Project.where(id: params[:project_id], api_token: params[:api_token]).exists?
          render json: { error: { errors: [{ message: t("controllers.api.v1.articles.invalid_api_token") }] } }, status: :unauthorized
        end
      end

      def find_project
        @project = Project.find_by_id(params[:project_id])

        unless @project
          respond_with(nil) do |format|
            format.html { redirect_to root_path, alert: t('controllers.api.v1.articles.project_not_found') }
            format.json { render json: { error: { errors: [{ message: t("controllers.api.v1.articles.project_not_found") }] } }, status: :not_found }
          end
        end
      end

      def find_article
        @article = @project.articles.find_by_name(params[:name])

        unless @article
          respond_with(nil) do |format|
            format.html { redirect_to root_path, alert: t("controllers.api.v1.articles.article_not_found") }
            format.json { render json: { error: { errors: [{ message: t("controllers.api.v1.articles.article_not_found") }] } }, status: :not_found }
          end
        end
      end

      def api_request?
        params[:api_token].present?
      end

      # ===== END AUTHENTICATION/AUTHORIZATION/VALIDATION ==============================================================

      # ===== START DECORATORS =========================================================================================
      def decorate_articles(articles)
        articles.map do |article|
          {
            name: article.name,
            ready: article.ready
          }
        end
      end

      def decorate_article(article)
        [
         :name, :project_id, :sections_hash, :ready, :loading, :description, :email,
         :base_rfc5646_locale, :targeted_rfc5646_locales,
         :first_import_requested_at, :last_import_requested_at,
         :first_import_started_at, :last_import_started_at,
         :first_import_finished_at, :last_import_finished_at,
         :first_completed_at, :last_completed_at,
         :created_at, :updated_at
        ].inject({}) do |hsh, field|
          hsh[field] = article.send(field)
          hsh
        end
      end
      # ===== END DECORATORS ===========================================================================================

      # ===== START PARAMS RELATED CODE ================================================================================
      def params_for_create
        params_for_update.merge(params.require(:article).permit(:base_rfc5646_locale)).
                          merge(created_via_api: api_request?, creator_id: current_user.try(:id))
      end

      def params_for_update
        hsh = params.require(:article).permit(:name, :description, :email, :priority)
        hsh[:due_date] = DateTime::strptime(params[:article][:due_date], "%m/%d/%Y") rescue '' if params[:article].try(:key?, :due_date)
        hsh[:targeted_rfc5646_locales] = params[:article][:targeted_rfc5646_locales] if params[:article].try(:key?, :targeted_rfc5646_locales)
        hsh[:sections_hash] = params[:article][:sections_hash] if params[:article].try(:key?, :sections_hash)
        hsh.merge(updater_id: current_user.try(:id))
      end
      # ===== END PARAMS RELATED CODE ==================================================================================

      def set_article_issues_presenter
        @article_issues_presenter ||= ArticleOrCommitIssuesPresenter.new(@article)
      end
    end
  end
end
