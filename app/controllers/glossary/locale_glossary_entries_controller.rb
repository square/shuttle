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

class Glossary::LocaleGlossaryEntriesController < ApplicationController
  before_filter :authenticate_user!, except: :manifest
  before_filter :translator_required, only: [:create, :edit, :update]

  before_filter :find_source_entry
  before_filter :find_locale_entry
  respond_to :json, :html

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
    @locale_entry = LocaleGlossaryEntry.new()
    @locale_entry.rfc5646_locale = params[:locale_glossary_entry][:rfc5646_locale]
    @locale_entry.source_glossary_entry = @source_entry
    
    if @locale_entry.save
      respond_to do |format|
        format.json { render json: @locale_entry.to_json, status: :created  }
      end 
    else
      puts @locale_entry.errors.to_json
      respond_to do |format|
        format.json { render json: @locale_entry.errors.to_json, status: :unprocessable_entity  }
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
  ## TODO: Possibly make it such that if it is approved, it can't be unchanged unless unapproved?
  def update
    if params[:review]
      return render json: false unless current_user.reviewer?
      @locale_entry.reviewer = current_user
      @locale_entry.approved = (params[:approved] == "true")
    end
    @locale_entry.copy = params[:locale_glossary_entry][:copy]
    @locale_entry.notes = params[:locale_glossary_entry][:notes]

    @locale_entry.save!
    respond_with(@locale_entry, :location => glossary_url)
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

  def edit 
    respond_with @source_entry, @locale_entry
  end 

  private
  # Find the requested source entry by source id.

  def find_source_entry
    @source_entry = SourceGlossaryEntry.find_by_id(params[:source_id])
  end


  # Find the requested locale entry by locale id.

  def find_locale_entry
    @locale_entry = LocaleGlossaryEntry.find_by_id(params[:id])
  end

end
