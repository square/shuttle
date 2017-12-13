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
  include Elasticsearch::DSL
  PER_PAGE = 50


  def initialize(form)
    @form = form
  end

  def search_query
    include_translated = form[:include_translated]
    include_approved = form[:include_approved]
    include_new = form[:include_new]
    include_block_tags = form[:include_block_tags]

    current_page = page
    query_filter = form[:query_filter]
    translation_ids_in_commit = form[:translation_ids_in_commit]
    article_id = form[:article_id]
    section_id = form[:section_id]
    locale = form[:locale]
    project_id = form[:project_id]
    project = form[:project]
    filter_source = form[:filter_source]

    search {
      query do
        filtered do
          if query_filter.present?
            if filter_source == 'source'
              query do
                match 'source_copy' do
                  query query_filter
                  operator 'and'
                end
              end
            elsif filter_source == 'translated'
              query do
                match 'copy' do
                  query query_filter
                  operator 'and'
                end
              end
            end
          end

          filter do
            bool do
              must { term project_id: project_id }
              must { term rfc5646_locale: locale.rfc5646 } if locale
              must { ids values: translation_ids_in_commit } if translation_ids_in_commit
              must { term article_id: article_id } if article_id.present?
              must { term section_id: section_id } if section_id.present?
              must { term section_active: true } if project.not_git? # active sections
              must { exists field: :index_in_section } if project.not_git? # active keys in sections
              must_not { term is_block_tag: true } if project.not_git? && !include_block_tags

              if include_translated && include_approved && include_new
                #include everything
              elsif include_translated && include_approved
                must { term translated: 1 }
              elsif include_translated && include_new
                should { missing field: 'approved', existence: true, null_value: true }
                should { term approved: 0 }
              elsif include_approved && include_new
                should { term approved: 1 }
                should { term translated: 0 }
              elsif include_approved
                must { term approved: 1 }
              elsif include_new
                should { term translated: 0 }
                should { term approved: 0 }
              elsif include_translated
                must { missing field: 'approved', existence: true, null_value: true }
                must { term translated: 1 }
              else
                # include nothing
                throw :include_nothing
              end
            end
          end
        end
      end

      if project.not_git?
        sort do
          by :section_id, order: 'asc'
          by :index_in_section, order: 'asc'
        end
      end

      from (current_page - 1) * PER_PAGE
      size PER_PAGE
    }.to_hash
  end

  def page
    form[:page]
  end

  def find_translations
    translations_in_es = Elasticsearch::Model.search(search_query, Translation).results
    translations = Translation
                       .where(id: translations_in_es.map(&:id))
                       .where('commits.revision': form[:commit])
                       .includes({key: [:project, :commits, :translations, :section, {article: :project}]}, :locale_associations)
    if form[:article_id]
      translations = translations.order('keys.section_id, keys.index_in_section')
    else
      translations = translations.order('commits_keys.created_at, keys.original_key')
    end

    # Don't sort the keys since they are sorted in the line above
    PaginatableObjects.new(translations, translations_in_es, page, PER_PAGE, false)
  end
end
