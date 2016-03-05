# Copyright 2016 Square Inc.
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

class LocaleProjectsShowFinder
  attr_reader :form
  PER_PAGE = 50


  def initialize(form)
    @form = form
  end

  def find_translations
    include_translated = form[:include_translated]
    include_approved   = form[:include_approved]
    include_new        = form[:include_new]
    include_block_tags = form[:include_block_tags]

    page       = form[:page]
    query_filter = form[:query_filter]
    translation_ids_in_commit = form[:translation_ids_in_commit]
    article_id   = form[:article_id]
    section_id   = form[:section_id]
    locale       = form[:locale]
    project_id   = form[:project_id]
    project      = form[:project]
    filter_source = form[:filter_source]

    translations_in_es = Translation.search do
      filter :term, project_id: project_id
      filter :term, rfc5646_locale: locale.rfc5646 if locale
      filter :ids, values: translation_ids_in_commit if translation_ids_in_commit
      filter :term, article_id: article_id if article_id.present?
      filter :term, section_id: section_id if section_id.present?
      filter :term, section_active: true if project.not_git?        # active sections
      filter :exists, field: :index_in_section if project.not_git?  # active keys in sections
      filter :not, { term: { is_block_tag: true } } if project.not_git? && !include_block_tags

      if query_filter.present?
        if filter_source == 'source'
          query { match 'source_copy', query_filter, operator: 'and' }
        elsif filter_source == 'translated'
          query { match 'copy', query_filter, operator: 'and' }
        end
      end

      if include_translated && include_approved && include_new
        # include everything
      elsif include_translated && include_approved
        filter :term, translated: 1
      elsif include_translated && include_new
        filter :or, [
                      {missing: {field: 'approved', existence: true, null_value: true}},
                      {term: {approved: 0}}]
      elsif include_approved && include_new
        filter :or, [
                      {term: {approved: 1}},
                      {term: {translated: 0}}]
      elsif include_approved
        filter :term, {approved: 1}
      elsif include_new
        filter :or, [
                      {term: {translated: 0}},
                      {term: {approved: 0}}]
      elsif include_translated
        filter :and,
               {missing: {field: 'approved', existence: true, null_value: true}},
               {term: {translated: 1}}
      else
        # include nothing
        throw :include_nothing
      end

      from (page - 1) * PER_PAGE
      size PER_PAGE

      if project.not_git?
        sort do
          by :section_id, 'asc'
          by :index_in_section, 'asc'
        end
      end
    end

    translations = Translation
                       .where(id: translations_in_es.map(&:id))
                       .includes({key: [:project, :translations, :section, {article: :project}]}, :locale_associations)

    PaginatableObjects.new(translations, translations_in_es, page, PER_PAGE)
  end
end
