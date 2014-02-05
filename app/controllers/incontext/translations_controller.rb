class Incontext::TranslationsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :translator_required

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
