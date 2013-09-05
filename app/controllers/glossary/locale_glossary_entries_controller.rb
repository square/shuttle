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
    @locale_entry = @source_entry.locale_glossary_entries.create(entry_params)
    
    respond_with @locale_entry, location: glossary_source_locales_url
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

  def update
    @locale_entry.assign_attributes(entry_params)

    @locale_entry.translated = true
    @locale_entry.translator = current_user

    @locale_entry.save
    respond_with @locale_entry, location: glossary_url
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


  # Marks a Translation as approved and records the reviewer as the current
  # User.
  #
  # Routes
  # ------
  #
  # * `PUT /projects/:project_id/keys/:key_id/translations/:id/approve`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                    |
  # |:-------------|:-----------------------------------|
  # | `project_id` | The slug of a Project.             |
  # | `key_id`     | The Slug of a Key in that project. |
  # | `id`         | The ID of a Translation.           |

  def approve
    @locale_entry.approved = true
    @locale_entry.reviewer = current_user
    @locale_entry.save!
    
    respond_with @locale_entry, location: glossary_source_locales_url
  end

  # Marks a Translation as rejected and records the reviewer as the current
  # User.
  #
  # Routes
  # ------
  #
  # * `PUT /projects/:project_id/keys/:key_id/translations/:id/reject`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                    |
  # |:-------------|:-----------------------------------|
  # | `project_id` | The slug of a Project.             |
  # | `key_id`     | The slug of a Key in that project. |
  # | `id`         | The ID of a Translation.           |

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

  def entry_params
    params.require(:locale_glossary_entry).permit(:copy, :notes, :rfc5646_locale)
  end

end
