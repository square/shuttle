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

# Controller that works with {Key Keys} associated with a {Commit}. This
# controller drives the key list view used by monitors to track commit
# progress.

class Commit::KeysController < ApplicationController
  # The number of records to return by default.
  PER_PAGE = 50

  before_filter :find_project
  before_filter :find_commit
  respond_to :json

  # Responds with a list of Keys associated with a Commit. 50 records are
  # returned at a time. The key JSON includes all translations of that Key.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/commits/:commit_id/keys`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                             |
  # |:-------------|:----------------------------|
  # | `project_id` | A {Project}'s slug.         |
  # | `commit_id`  | The revision of a {Commit}. |
  #
  # Query Parameters
  # ----------------
  #
  # |          |                                                            |
  # |:---------|:-----------------------------------------------------------|
  # | `offset` | An offset to start at, for pagination.                     |
  # | `limit`  | The number of keys to return, for pagination (default 50). |
  # | `query`  | A string to filter translation keys by.                    |

  def index
    offset = params[:offset].to_i
    limit  = params[:limit].to_i
    limit = PER_PAGE if limit < 1

    @keys = @commit.keys.by_key.offset(offset).limit(limit).preload(:translations, :slugs)

    case params[:status]
      when 'approved'
        @keys = @keys.where(ready: true)
      when 'pending'
        @keys = @keys.where(ready: false)
    end

    if params[:filter].present?
      @keys = @keys.original_key_query(params[:filter])
    end

    respond_with(@keys) do |format|
      format.json { render json: decorate(@keys) }
    end
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end

  def find_commit
    @commit = @project.commits.for_revision(params[:commit_id]).first!
  end

  def decorate(keys)
    keys.map do |key|
      key.as_json.merge(
          translations: key.translations.map do |translation|
            translation.as_json.merge(
                url: if current_user.translator?
                       edit_project_key_translation_url(@project, translation.key, translation)
                     else
                       project_key_translation_url(@project, translation.key, translation)
                     end
            )
          end
      )
    end
  end
end
