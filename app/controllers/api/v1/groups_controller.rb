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
# allow users to create/update/view Groups.
#
# If there is an `api_token`, the request will be authenticated via that token;
# otherwise, it will be authenticated via session using the `authenticate_user!`
# method that's used everywhere else in the application.

module API
  module V1
    class GroupsController < ApplicationController
      respond_to :json, only: [:index, :create, :update, :destroy]

      skip_before_filter :authenticate_user!,        if: :api_request?
      skip_before_action :verify_authenticity_token, if: :api_request?
      before_filter :authenticate_with_api_token!,   if: :api_request?

      before_filter :find_project
      before_filter :find_group, only: [:show, :update, :destroy]

      # EXTERNAL ONLY
      #
      # Returns all Groups in the Project.
      #
      # Routes
      # ------
      #
      # * `/api/v1/projects/:project_id/groups(.format)?api_token=:api_token`
      #
      # Path/Url Parameters
      # -------------------
      #
      # |              |                              |
      # |:-------------|:-----------------------------|
      # | `project_id` | The id of a Project.         |
      # | `api_token`  | The api token for a Project. |

      def index
        respond_with @project do |format|
          format.json { render json: decorate_groups }
        end
      end

      # Creates a Group in a Project.
      #
      # Routes
      # ------
      #
      # * `POST /api/v1/projects/:project_id/groups(.format)(?api_token=:api_token)`
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
      # |                   |                                                                                                               |
      # |:------------------|:----------------------------------------|
      # | `name`            | The name of the group.                  |
      # | `article_names`   | The list of article names in the group  |
      #
      # Returns
      # -------
      # a map from article names to their readiness

      def create
        create_params = params_for_create

        if group_exists?(create_params[:name])
          render_error_with_message(t('controllers.api.v1.groups.group_found'), :bad_request)
          return
        end

        group = @project.groups.new(name: create_params[:name])
        errors = update_article_groups(group, create_params)
        if errors
          render_errors(errors)
          return
        end

        respond_with @project do |format|
          format.json { render json: decorate_group(group) }
        end
      end

      # Returns a Group.
      #
      # Routes
      # ------
      #
      # * `GET /api/v1/projects/:project_id/groups/:name(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      # | `name`       | The `name` of the group.                                                                |
      #
      # Returns
      # -------
      # a map from article names to their readiness

      def show
        respond_with @project do |format|
          format.json { render json: decorate_group(@group) }
        end
      end

      # Updates a Group in a Project.
      #
      # Routes
      # ------
      #
      # * `PATCH /api/v1/projects/:project_id/groups/:name(.format)(?api_token=:api_token)`
      # * `PUT /api/v1/projects/:project_id/groups/:name(.format)(?api_token=:api_token)`
      #
      # Path/Url Parameters
      # ---------------
      #
      # |              |                                                                                         |
      # |:-------------|:----------------------------------------------------------------------------------------|
      # | `project_id` | The id of a Project.                                                                    |
      # | `api_token`  | The api token for a Project. Not required if the request is coming from internal views. |
      # | `name`       | The `name` of the Group.                                                                |
      #
      # Body Parameters
      # ---------------
      #
      # |                   |                                                                                                               |
      # |:------------------|:----------------------------------------|
      # | `article_names`   | The list of article names in the group  |
      #
      # Returns
      # -------
      # a map from article names to their readiness

      def update
        update_params = params_for_update

        errors = update_article_groups(@group, update_params)
        if errors
          render_errors(errors)
          return
        end

        respond_with @project do |format|
          format.json { render json: decorate_group(@group) }
        end
      end

      def destroy
        @group.destroy

        respond_with @project do |format|
          format.json { render json: { status: true } }
        end
      end

      # private

      # ===== START AUTHENTICATION/AUTHORIZATION/VALIDATION ============================================================
      def authenticate_with_api_token!
        unless Project.where(id: params[:project_id], api_token: params[:api_token]).exists?
          render_error_with_message(t('controllers.api.v1.groups.invalid_api_token'), :unauthorized)
        end
      end

      def find_project
        @project = Project.find_by_id(params[:project_id])

        unless @project
          render_error_with_message(t('controllers.api.v1.groups.project_not_found'), :not_found)
        end
      end

      def find_group
        @group = Group.find_by_name(params[:name])

        unless @group
          render_error_with_message(t('controllers.api.v1.groups.group_not_found'), :not_found)
        end
      end

      def api_request?
        params[:api_token].present?
      end

      # ===== END AUTHENTICATION/AUTHORIZATION/VALIDATION ==============================================================

      # ===== START DECORATORS =========================================================================================
      def decorate_groups
        @project.groups.map(&:name).sort
      end

      def decorate_group(group)
        {
          name: group.name,
          display_name: group.display_name,
          description: group.description,
          articles: group.article_groups.includes(:article).order(:index_in_group).map do |article_group|
            {
              name: article_group.article.name,
              ready: article_group.article.ready?
            }
          end
        }
      end
      # ===== END DECORATORS ===========================================================================================

      # ===== START PARAMS RELATED CODE ================================================================================
      def params_for_create
        hash = params.require(:group).permit(:name, :display_name, :description, :article_names => [])
        hash.merge(created_via_api: api_request?, creator_id: current_user.try(:id))
      end

      def params_for_update
        hash = params.require(:group).permit(:description, :display_name, :article_names => [])
        hash[:priority] = params[:group][:priority] # default to nil
        hash[:due_date] = DateTime::strptime(params[:group][:due_date], "%m/%d/%Y") rescue '' if params[:group].try(:key?, :due_date)
        hash.merge(updater_id: current_user.try(:id))
      end
      # ===== END PARAMS RELATED CODE ==================================================================================

      def group_exists?(name)
        @project.groups.where(name: name).count > 0
      end

      def render_error_with_message(message, status)
        render_errors([{ message: message }], status)
      end

      def render_errors(errors, status=:bad_request)
        respond_with(nil) do |format|
          format.json { render json: { error: { errors: errors } }, status: status }
        end
      end

      def update_article_groups(group, update_params)
        errors = []

        if update_params[:article_names]
          article_groups = update_params[:article_names].each_with_index.map do |article_name, index|
            article = @project.articles.where(name: article_name).first
            if article
              ArticleGroup.new(group: group, article: article, index_in_group: index)
            else
              errors << t('controllers.api.v1.groups.article_not_found', article_name: article_name)
            end
          end
          if errors.present?
            return errors
          end
          group.article_groups = article_groups
        end

        if update_params[:priority]
          group.priority = update_params[:priority]
        end

        if update_params[:due_date]
          group.due_date = update_params[:due_date]
        end

        if update_params[:description]
          group.description = update_params[:description]
        end

        if update_params[:display_name]
          group.display_name = update_params[:display_name]
        end

        group.save!
        nil
      end
    end
  end
end
