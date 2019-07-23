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
require 'paginatable_objects'

class LocaleProjectsShowFinder
  attr_reader :form
  PER_PAGE = 50


  def initialize(form)
    @form = form
  end

  def search_query
    query_params = []
    text_to_search = form[:query_filter]
    if text_to_search.present?
      if form[:filter_source] == 'source'
        query_params << { match: { source_copy: {query: text_to_search, operator: 'and' } } }
      elsif form[:filter_source] == 'translated'
        query_params << { match: { copy: {query: text_to_search, operator: 'and'} } }
      end
    end

    filter_params = []
    filter_params << { term: { project_id: form[:project_id] } }
    filter_params << { term: { rfc5646_locale: form[:locale].rfc5646 } } if form[:locale]
    filter_params << { ids: { values: form[:translation_ids_in_commit] } } if form[:translation_ids_in_commit]
    filter_params << { term: { article_id: form[:article_id] } } if form[:article_id].present?
    filter_params << { ids: { values: form[:translation_ids_in_assest] } } if form[:translation_ids_in_assest]
    filter_params << { term: { section_id: form[:section_id] } } if form[:section_id].present?
    filter_params << { term: { section_active: true } } if form[:project].article?
    filter_params << { exists: { field: :index_in_section } } if form[:project].article?
    filter_params << { bool: { must_not: { term: { is_block_tag: true  } } } } if form[:project].article? && !form[:include_block_tags]

    state_params = []
    state_params << TranslationsIndex::TRANSLATION_STATE_APPROVED if form[:include_approved]
    state_params << TranslationsIndex::TRANSLATION_STATE_TRANSLATED if form[:include_translated]
    state_params << TranslationsIndex::TRANSLATION_STATE_NEW if form[:include_new]
    state_params << TranslationsIndex::TRANSLATION_STATE_REJECTED if form[:include_new]
    filter_params << { terms: { translation_state: state_params } } unless state_params.empty?

    query = TranslationsIndex.query(query_params).filter(filter_params)
    query = query.order(section_id: :asc, index_in_section: :asc) if form[:project].article?
    query = query.offset((page-1) * PER_PAGE).limit(PER_PAGE)

    return query
  end

  def page
    form[:page]
  end

  def find_translations
    include_tables = [{ key: [:project, :assets, :translations, :section, { article: [:project, article_groups: :group] }] }, :locale_associations, :translation_changes]

    scope = -> { includes(include_tables) }
    if form[:article_id]
      scope = -> { includes(include_tables).order('keys.section_id, keys.index_in_section') }
    elsif form[:commit]
      scope = -> { includes(include_tables).order('translations.created_at') }
    elsif form[:group]
      scope = -> { includes(include_tables).order('article_groups.index_in_group, keys.section_id, keys.index_in_section') }
    end

    translations = search_query.load(scope: scope)
    return PaginatableObjects.new(translations, page, PER_PAGE)
  end
end
