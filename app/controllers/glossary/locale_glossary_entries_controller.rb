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
  before_filter :reviewer_required, only: [:approve, :reject]

  before_filter :find_source_entry
  before_filter :find_locale_entry, except: [:create]
  respond_to :json, :html

  # Creates a new locale glossary entry for the source glossary entry in the 
  # specified locale.  Note that a copy and notes are optional for the new 
  # locale glossary entry.
  #
  # Routes
  # ------
  #
  # * `POST /glossary/sources/:source_id/locales`
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                                      |
  # |:------------|:-----------------------------------------------------|
  # | `source_id` | The id of the source entry that is being translated. |
  #
  # Body Parameters
  # ---------------
  #
  # |                  |                                                        |
  # |:-----------------|:-------------------------------------------------------|
  # | `copy`           | The localized translation of the source copy.          |
  # | `notes`          | Any additional information regarding the translation.  |
  # | `rfc5646_locale` | The locale that the source copy is being translated to |


  def create
    @locale_entry = @source_entry.locale_glossary_entries.create(create_params)
    respond_with @locale_entry, location: glossary_source_locales_url
  end

  # Updates a locale glossary entry. 
  #
  # Routes
  # ------
  #
  # * `PATCH /glossary/sources/:source_id/locales/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                                            |
  # |:------------|:-----------------------------------------------------------|
  # | `source_id` | The id of the source entry of the locale glossary entry.   |
  # | `id`        | The id of the locale glossary entry that is being updated. |
  #
  # Body Parameters
  # ---------------
  #
  # |         |                                                       |
  # |:--------|:------------------------------------------------------|
  # | `copy`  | The localized translation of the source copy.         |
  # | `notes` | Any additional information regarding the translation. |

  def update
    @locale_entry.assign_attributes(update_params)

    @locale_entry.translated = true
    @locale_entry.translator = current_user

    @locale_entry.save
    respond_with @locale_entry, location: glossary_url
  end

  # Displays a large-format glossary entry edit page which contains a reference to 
  # its respective source glossary entry's data.
  #
  # Routes
  # ------
  #
  # * `GET /glossary/sources/:source_id/locales/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                                            |
  # |:------------|:-----------------------------------------------------------|
  # | `source_id` | The id of the source entry of the locale glossary entry.   |
  # | `id`        | The id of the locale glossary entry that is being editted. |

  def edit 
    respond_with @source_entry, @locale_entry
  end 


  # Marks a locale glossary entry as approved and records the reviewer as the current
  # User.
  #
  # Routes
  # ------
  #
  # * `PATCH /glossary/sources/:source_id/locales/:id/approve`
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                                             |
  # |:------------|:------------------------------------------------------------|
  # | `source_id` | The id of the source entry of the locale glossary entry.    |
  # | `id`        | The id of the locale glossary entry that is being approved. |

  def approve
    @locale_entry.approved = true
    @locale_entry.reviewer = current_user
    @locale_entry.save!
    
    respond_with @locale_entry, location: glossary_source_locales_url
  end

  # Marks a locale glossary entry as rejected and records the reviewer as the current
  # User.
  #
  # Routes
  # ------
  #
  # * `PATCH /glossary/sources/:source_id/locales/:id/reject`
  #
  # Path Parameters
  # ---------------
  #
  # |             |                                                             |
  # |:------------|:------------------------------------------------------------|
  # | `source_id` | The id of the source entry of the locale glossary entry.    |
  # | `id`        | The id of the locale glossary entry that is being rejected. |

  def reject
    @locale_entry.approved = false
    @locale_entry.reviewer = current_user
    @locale_entry.save!
    
    respond_with @locale_entry, location: glossary_source_locales_url
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

  def create_params
    params.require(:locale_glossary_entry).permit(:copy, :notes, :rfc5646_locale)
  end

  def update_params
    params.require(:locale_glossary_entry).permit(:copy, :notes)
  end
end
