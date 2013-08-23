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
  respond_to :json

  def create
    lGlossaryEntry = LocaleGlossaryEntry.new()
    lGlossaryEntry.rfc5646_locale = params[:locale]
    lGlossaryEntry.source_glossary_entry = SourceGlossaryEntry.find(params[:source_glossary_entry_id])
    lGlossaryEntry.copy = params[:copy]
    lGlossaryEntry.notes = params[:notes]
    
    if lGlossaryEntry.save
      render :json => true
    else
      render :json => false
    end
  end

  ### TODO: Possibly make it such that if it is approved, it can't be unchanged unless unapproved?
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
    render json: true
  end
end
