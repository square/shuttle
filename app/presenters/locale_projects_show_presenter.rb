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

class LocaleProjectsShowPresenter
  include ActionView::Helpers::TextHelper
  include TranslationDecoration
  include Rails.application.routes.url_helpers

  attr_reader :form
  def initialize(project, form)
    @project = project
    @form = form
  end

  # @return [Array<Pair<String, String>>] an array of selectable options for Commits

  def selectable_commits
    @_selectable_commits ||= @project.commits.order('committed_at DESC').
        map { |c| ["#{c.revision_prefix}: #{truncate c.message}", c.revision] }.unshift(['ALL COMMITS', nil])
  end

  # @return [Commit, nil] selected Commit if there is one

  def selected_commit
    @_selected_commit ||= @project.commits.for_revision(form[:commit]).first
  end

  # @return [Article, nil] selected Article if there is one

  def selected_article
    @_selected_article ||= @project.articles.find_by_id(form[:article_id])
  end

  # @return [Array<Pair<String, String>>] an array of selectable options for Sections

  def selectable_sections
    @_selectable_sections ||= (selected_article ? selected_article : @project).sections.merge(Section.active).
        map {|s| [truncate(s.name), s.id]}.unshift(['ALL SECTIONS', nil])
  end

  # Searches Article's active sections if an Article is selected, searches Project's active sections otherwise.
  #
  # @return [Section, nil] selected Section if there is one.

  def selected_section
    @_selected_section ||= (selected_article ? selected_article : @project).sections.merge(Section.active).find_by_id(form[:section_id])
  end

  def filter_string
    form[:query_filter]
  end

  def selected_filter_source
    form[:filter_source]
  end

  def include_translated?
    form[:include_translated]
  end

  def include_new?
    form[:include_new]
  end

  def include_approved?
    form[:include_approved]
  end

  def decorate_translations(translations)
    @_decorate_translations ||= decorate(translations).to_json
  end
end
