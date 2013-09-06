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

  before_filter :find_source_entry, except: [:index, :create]

  respond_to :json, :only => [:index, :create]
  respond_to :html
  

  # Renders JSON information about every source glossary entry and their respective
  # locale glossary entries.
  #
  # Routes
  # ------
  #
  # * `GET /glossary/sources`

  def index
    @entries = SourceGlossaryEntry.order('source_copy_prefix ASC')
    respond_with(@entries) 
  end


  # Creates a new source glossary entry. Note that the context, notes, and are optional for the new 
  # source glossary entry.
  #
  # Routes
  # ------
  #
  # * `POST /glossary/sources`
  #
  # Body Parameters
  # ---------------
  #
  # |                         |                                                           |
  # |:------------------------|:----------------------------------------------------------|
  # | `source_copy`           | The text that will be translated into various locales     |
  # | `source_rfc5646_locale` | The source locale of the entry                            |
  # | `context`               | The context in which the copy is being used               |
  # | `notes`                 | Any additional information regarding translation or usage |
  # | `due_date`              | A soft due date for the translation                       |

  def create
    @source_entry = SourceGlossaryEntry.create(create_params)
    respond_with @source_entry, :location => glossary_sources_url
  end

  # Displays a large-format glossary entry edit page.
  #
  # Routes
  # ------
  #
  # * `GET /glossary/sources/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                                      |
  # |:-----|:-------------------------------------|
  # | `id` | The id of the source glossary entry. |

  def edit
    respond_with @source_entry
  end 

  # Updates a source glossary entry with new notes and context.
  #
  # Routes
  # ------
  #
  # * `PATCH /glossary/sources/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                                      |
  # |:-----|:-------------------------------------|
  # | `id` | The id of the source glossary entry. |
  #
  # Body Parameters
  # ---------------
  #
  # |               |                                                           |
  # |:--------------|:----------------------------------------------------------|
  # | `source_copy` | The text that will be translated into various locales     |
  # | `context`     | The context in which the copy is being used               |
  # | `notes`       | Any additional information regarding translation or usage |
  # | `due_date`    | A soft due date for the translation                       |

  def update
    @source_entry.update_attributes(update_params)
    respond_with @source_entry, :location => glossary_url
  end

  # Removes a source glossary entry and all of its locale glossary entries.
  #
  # Routes
  # ------
  #
  # * `DELETE /glossary/sources/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                                      |
  # |:-----|:-------------------------------------|
  # | `id` | The id of the source glossary entry. |

  def destroy
    respond_with @source_entry.destroy(), :location => glossary_url
  end

  private

  # Find the requested source entry by id.

  def find_source_entry
    @source_entry = SourceGlossaryEntry.find params[:id]
  end

  def create_params
    params.require(:source_glossary_entry).permit(:source_copy, :context, :notes, :due_date, :source_rfc5646_locale)
  end

  # The permitted fields that can be updated. 

  def update_params
    params.require(:source_glossary_entry).permit(:source_copy, :context, :notes, :due_date)
  end

end
