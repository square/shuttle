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

module Api
  module V1
    class ArticlesController < ApplicationController
      respond_to :json

      skip_before_filter :authenticate_user!
      skip_before_action :verify_authenticity_token
      before_filter :authenticate_and_find_project
      before_filter :find_article, only: [:show, :update, :status, :manifest]

      # Returns all Articles in the Project.
      #
      # Routes
      # ------
      #
      # * `GET /articles?api_token=:api_token`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |             |                              |
      # |:------------|:-----------------------------|
      # | `api_token` | The api token for a Project. |

      def index
        respond_with @project.articles do |format|
          format.json { render json: decorate_articles(@project.articles) }
        end
      end

      # Creates an Article in a Project.
      #
      # Routes
      # ------
      #
      # * `POST /articles?api_token=:api_token`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |             |                              |
      # |:------------|:-----------------------------|
      # | `api_token` | The api token for a Project. |
      #
      # Body Parameters
      # ---------------
      #
      # |                            |                                                                            |
      # |:---------------------------|:---------------------------------------------------------------------------|
      # | `name`                     | The `name` of the Article                                                  |
      # | `sections_hash`            | A hash mapping Section names to Section source copies                      |
      # | `description`              | The description of the Article                                             |
      # | `email`                    | An email address which can be used for communication regarding the Article |
      # | `base_rfc5646_locale`      | Base rfc5646 locale of the Article                                         |
      # | `targeted_rfc5646_locales` | Targeted rfc5646 locales for the Article                                   |

      def create
        article = @project.articles.create(params_for_create)

        respond_with article do |format|
          format.json do
            if article.errors.blank?
              render json: decorate_article(article), status: :accepted
            else
              render json: { error: { errors: article.errors } }, status: :bad_request
            end
          end
        end
      end

      # Returns a Article.
      #
      # Routes
      # ------
      #
      # * `GET /articles/:name?api_token=:api_token`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |             |                              |
      # |:------------|:-----------------------------|
      # | `api_token` | The api token for a Project. |
      # | `name`      | The `name` of the Article.   |

      def show
        respond_with @article do |format|
          format.json do
            render json: decorate_article(@article)
          end
        end
      end

      # Updates a Article in a Project.
      #
      # Doesn't allow an update if there is a pending import or an import is in progress and the update
      # attempts to change a sensitive attribute that would trigger a re-import
      #
      # Routes
      # ------
      #
      # * `PATCH /articles/:name?api_token=:api_token`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |             |                              |
      # |:------------|:-----------------------------|
      # | `api_token` | The api token for a Project. |
      # | `name`      | The `name` of the Article.   |
      #
      # Body Parameters
      # ---------------
      #
      # |                            |                                                                            |
      # |:---------------------------|:---------------------------------------------------------------------------|
      # | `sections_hash`            | A hash mapping Section names to Section source copies                      |
      # | `description`              | The description of the Article                                             |
      # | `email`                    | An email address which can be used for communication regarding the Article |
      # | `targeted_rfc5646_locales` | Targeted rfc5646 locales for the Article                                   |

      def update
        _params_for_update = params_for_update # cache
        if !@article.last_import_finished? && Article::FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED.any? do |field|
                    # if there is a pending import or an import is in progress, and an import triggering field is trying to be changed
                    _params_for_update.key?(field) && (_params_for_update[field] != @article.send(field.to_sym))
                  end
          @article.errors.add(:base, :not_finished)
        else
          @article.update(_params_for_update)
        end

        respond_with @article do |format|
          format.json do
            if @article.errors.blank?
              render json: decorate_article(@article), status: :accepted
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
      # * `GET /articles/:name/manifest?api_token=:api_token`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |             |                              |
      # |:------------|:-----------------------------|
      # | `api_token` | The api token for a Project. |
      # | `name`      | The `name` of the Article.   |

      def manifest
        respond_with @article do |format|
          format.json do
            begin
              render json: Exporter::Article.new(@article).export
            rescue Exporter::Article::Error => e
              render json: { error: { errors: [{ message: e.inspect }] } }, status: :bad_request
            end
          end
        end
      end

      private

      # ===== START AUTHENTICATION/AUTHORIZATION/VALIDATION ============================================================
      def authenticate_and_find_project
        unless params[:api_token].present? && @project = Project.find_by_api_token(params[:api_token])
          render json: { error: { errors: [{ message: t("controllers.api.v1.articles.invalid_api_token") }] } }, status: :unauthorized
        end
      end

      def find_article
        unless @article = @project.articles.find_by_name(params[:name])
          render json: { error: { errors: [{ message: t("controllers.api.v1.articles.article_not_found") }] } }, status: :not_found
        end
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
        params_for_update.merge(params.permit(:name, :base_rfc5646_locale))
      end

      def params_for_update
        hsh = params.permit(:description, :email, :priority)
        hsh[:due_date] = DateTime::strptime(params[:due_date], "%m/%d/%Y") rescue '' if params.key?(:due_date)
        hsh[:targeted_rfc5646_locales] = params[:targeted_rfc5646_locales] if params.key?(:targeted_rfc5646_locales)
        hsh[:sections_hash] = params[:sections_hash] if params.key?(:sections_hash)
        hsh
      end
      # ===== END PARAMS RELATED CODE ==================================================================================
    end
  end
end
