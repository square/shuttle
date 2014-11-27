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

class ScreenshotsController < ApplicationController
  before_filter :monitor_required, only: [:create]

  before_filter :find_project
  before_filter :find_commit

  respond_to :json

  # Creates a new screenshot
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/screenshots`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `commit_id`  | The SHA of a Commit.   |

  def create
    @screenshot = @commit.screenshots.create(screenshot_params)
    respond_with @screenshot, nothing: true
  end

  # Sends an e-mail to the commit author and developer requesting screenshots.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/commits/:id/screenshots/request`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                        |
  # |:-------------|:-----------------------|
  # | `project_id` | The slug of a Project. |
  # | `commit_id`  | The SHA of a Commit.   |

  def request_screenshots
    ScreenshotMailer.request_screenshot(@commit, current_user).deliver
    respond_to do |format|
      format.any { head :ok }
    end
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end

  def find_commit
    @commit = @project.commits.for_revision(params[:commit_id]).first!
  end

  def screenshot_params
    params.require(:screenshot).permit(:image)
  end
end
