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

# Restful controller for working with
# {LocaleGlossaryEntry LocaleGlossaryEntries}.

class Glossary::LocaleGlossaryEntriesController < ApplicationController
  before_filter :translator_required, only: [:create, :edit, :update]
  before_filter :reviewer_required, only: [:approve, :reject]
  before_filter :locale_access_required, except: :create

  before_filter :find_source_entry
  before_filter :find_locale_entry, except: :create
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
  # |             |                                  |
  # |:------------|:---------------------------------|
  # | `source_id` | The ID of a SourceGlossaryEntry. |
  #
  # Body Parameters
  # ---------------
  #
  # |                         |                                                       |
  # |:------------------------|:------------------------------------------------------|
  # | `locale_glossary_entry` | Parameterized hash of LocaleGlossaryEntry attributes. |

  def create
    return unless verify_locale_access(create_params[:rfc5646_locale])

    @locale_entry = @source_entry.locale_glossary_entries.create(create_params)
    respond_with @source_entry, @locale_entry, location: edit_glossary_source_locale_url(@source_entry, @locale_entry)
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
  # |             |                                  |
  # |:------------|:---------------------------------|
  # | `source_id` | The ID of A SourceGlossaryEntry. |
  # | `id`        | The ID of a LocaleGlossaryEntry. |
  #
  # Body Parameters
  # ---------------
  #
  # |                         |                                                       |
  # |:------------------------|:------------------------------------------------------|
  # | `locale_glossary_entry` | Parameterized hash of LocaleGlossaryEntry attributes. |

  def update
    @locale_entry.assign_attributes(update_params)

    @locale_entry.translated = true
    @locale_entry.translator = current_user

    @locale_entry.save
    respond_with @source_entry, @locale_entry, location: glossary_url
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
    
    respond_with @source_entry, @locale_entry, location: glossary_source_locales_url
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
    
    respond_with @source_entry, @locale_entry, location: glossary_source_locales_url
  end

  private

  # Find the requested source entry by source id.

  def find_source_entry
    @source_entry = SourceGlossaryEntry.find params[:source_id]
  end

  # Find the requested locale entry by locale id.

  def find_locale_entry
    @locale_entry = @source_entry.locale_glossary_entries.find_by_rfc5646_locale! params[:id]
  end

  def create_params
    params.require(:locale_glossary_entry).permit(:copy, :notes, :rfc5646_locale)
  end

  def update_params
    params.require(:locale_glossary_entry).permit(:copy, :notes)
  end

  def locale_access_required
    verify_locale_access params[:id]
  end

  def verify_locale_access(param)
    if current_user.has_access_to_locale?(param)
      return true
    else
      respond_to do |format|
        format.html { redirect_to root_url, alert: t('controllers.locale.projects.locale_access_required') }
        format.any { head :forbidden }
      end
      return false
    end
  end
end
