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

class GlossaryEntriesController < ApplicationController
  before_filter :authenticate_user!, except: :manifest
  respond_to :json

  def index
    # confirm valid locale
    GlossaryEntry.ensure_entries_exist_in_locale params[:locale_id]
    render json: GlossaryEntry.where(rfc5646_locale: params[:locale_id]).order('source_copy_prefix ASC')
  end

  def create
    ge = GlossaryEntry.new()
    ge.source_copy = params[:source_copy]
    ge.copy = params[:source_copy]
    ge.source_rfc5646_locale = "en"
    ge.rfc5646_locale = "en"
    if ge.save
      render :json => true
    else
      render :json => false
    end
  end

  def update
    ge = GlossaryEntry.find(params[:id])
    if params[:review]
      return render json: false unless current_user.reviewer?
      ge.reviewer = current_user
      ge.approved = (params[:approved] == "true")
    end
    ge.copy = params[:copy]

    ge.save!
    render json: true
  end
end
