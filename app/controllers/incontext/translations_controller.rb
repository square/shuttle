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

class Incontext::TranslationsController < ApplicationController
  before_filter :translator_required
  before_filter :allow_iframe_requests

  before_filter :find_project
  before_filter :find_commit
  before_filter :find_key
  before_filter :find_translation

  layout false
  respond_to :html

  def show
    if @translation.translated?
      render text: @translation.copy
    else
      render text: "<pending> #{@translation.source_copy}"
    end
  end

  def edit
    respond_with @translation, location: incontext_translation_url(@project, @commit, @key, @translation)
  end

  private
  def allow_iframe_requests
    response.headers.delete('X-Frame-Options')
  end

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end

  def find_commit
    @commit = @project.commits.for_revision(params[:commit_id]).first!
  end

  def find_key
    @key = @commit.keys.for_key(params[:key_id]).first!
  end

  def find_translation
    @translation = @key.translations.where(rfc5646_locale: params[:id]).first!
  end
end
