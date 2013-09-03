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
    lGlossaryEntry = LocaleGlossaryEntry.new()
    lGlossaryEntry.rfc5646_locale = params[:locale]
    lGlossaryEntry.source_glossary_entry = SourceGlossaryEntry.find(params[:source_glossary_entry_id])
    lGlossaryEntry.copy = params[:copy]
    lGlossaryEntry.notes = params[:notes]
    
    if lGlossaryEntry.save
      respond_with(true)
    else
      respond_with(true)
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
    lGlossaryEntry = LocaleGlossaryEntry.find(params[:id])
    if params[:review]
      return render json: false unless current_user.reviewer?
      lGlossaryEntry.reviewer = current_user
      lGlossaryEntry.approved = (params[:approved] == "true")
    end
    lGlossaryEntry.copy = params[:copy]
    lGlossaryEntry.notes = params[:notes]

    lGlossaryEntry.save!
    respond_with(true)
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
    puts @source_entry
    puts @locale_entry
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
