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
  respond_to :json

  def index
    returnEntries = []

    SourceGlossaryEntry.all.order('source_copy_prefix ASC').each do |sGlossaryEntry| 
      newEntry =  { 'source_copy' => sGlossaryEntry.source_copy,
                    'source_locale' => sGlossaryEntry.source_rfc5646_locale,
                    'context' => sGlossaryEntry.context,
                    'notes' => sGlossaryEntry.notes,
                    'locale_glossary_entries' => {}
                  }
      sGlossaryEntry.locale_glossary_entries.each do |lGlossaryEntry| 
        newEntry['locale_glossary_entries'][lGlossaryEntry.rfc5646_locale] = { 
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

    render json: returnEntries
  end

  def create
    sGlossaryEntry = SourceGlossaryEntry.new()
    sGlossaryEntry.source_copy = params[:source_copy]
    sGlossaryEntry.notes = params[:notes]
    sGlossaryEntry.context = params[:context]
    sGlossaryEntry.source_rfc5646_locale = "en" ## Possibly enable other sources
    puts params.inspect
    puts sGlossaryEntry.inspect

    if sGlossaryEntry.save
      render :json => true
    else
      render :json => false
    end
  end

  def update
    sGlossaryEntry = SourceGlossaryEntry.find(params[:id])
    sGlossaryEntry.source_copy = params[:source_copy]
    sGlossaryEntry.notes = params[:notes]
    sGlossaryEntry.context = params[:context]

    sGlossaryEntry.save!
    render json: true
  end

  ## ADD DESTROY SUPPORT
  # def destroy
  #   SourceGlossaryEntry.find(params[:id]).destroy()
  #   render json: true
  # end
end
