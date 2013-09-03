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

class Glossary::SourceGlossaryEntriesController < ApplicationController
  before_filter :authenticate_user!, except: :manifest
  before_filter :reviewer_required, only: [:edit, :update]
  before_filter :admin_required, only: [:destroy]

  before_filter :find_source_entry

  respond_to :json, :only => [:index, :create]
  respond_to :html
  

  # Renders JSON information about every source glossary entry and their respective
  # locale glossary entries..
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

  def index
    returnEntries = []

    SourceGlossaryEntry.all.order('source_copy_prefix ASC').each do |sGlossaryEntry| 
      newEntry =  { 
                    'id' => sGlossaryEntry.id,
                    'source_copy' => sGlossaryEntry.source_copy,
                    'source_locale' => sGlossaryEntry.source_rfc5646_locale,
                    'context' => sGlossaryEntry.context,
                    'notes' => sGlossaryEntry.notes,
                    'locale_glossary_entries' => {}
                  }
      sGlossaryEntry.locale_glossary_entries.each do |lGlossaryEntry| 
        newEntry['locale_glossary_entries'][lGlossaryEntry.rfc5646_locale] = { 
          'id' => lGlossaryEntry.id,
          'copy' => lGlossaryEntry.copy, 
          'notes' => lGlossaryEntry.notes, 
          'translator' => lGlossaryEntry.translator,
          'translated' => lGlossaryEntry.translated,
          'reviewer' => lGlossaryEntry.reviewer,
          'approved' => lGlossaryEntry.approved
        }
      end
      returnEntries << newEntry
    end 

    respond_with(returnEntries)
  end


  # Creates a new source glossary entry.
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
    @source_entry = SourceGlossaryEntry.create(params[:source_glossary_entry].to_hash)
    if @source_entry.valid?
      respond_to do |format|
        format.json { render json: @source_entry.to_json, status: :created  }
      end 
    else 
      respond_to do |format|
        format.json { render json: @source_entry.errors.to_json, status: :unprocessable_entity  }
      end 
    end 
    # respond_with(@source_entry, :include => :status)
  end

  def edit
    respond_with @source_entry
  end 

  # Updates a source glossary entry with new notes and context.
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
    @source_entry.update_attributes(entry_params)
    respond_with(@source_entry, :location => glossary_url)
  end


  # Removes a source glossary entry and all of its locale glossary entries..
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
    respond_with(@source_entry.destroy(), :location => glossary_url)
  end

  private

  # Find the requested source entry by id.

  def find_source_entry
    @source_entry = SourceGlossaryEntry.find_by_id(params[:id])
  end

  def entry_params
    params.require(:source_glossary_entry).permit(:source_copy, :context, :notes)
  end

end
