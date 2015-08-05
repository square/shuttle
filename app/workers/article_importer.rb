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

# A worker which will start an import for an {Article}.
# This worker is only scheduled in `import!` method of {Article} after it's become
# known that a re-import is needed.

class ArticleImporter
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker by calling `#import_strings` on {SectionImporter::Core}.
  # Sets `loading` to true.
  #
  # @param [Fixnum] article_id The ID of a Article
  # @param [true, false] force_import_sections to determine if active Sections should be imported
  #     regardless of changes to Section. An example usage of this would be when targeted_rfc5646_locales
  #     of the Article changes.

  def perform(article_id, force_import_sections=false)
    article = Article.find(article_id)
    article.update_import_starting_fields!

    # Read Section model's documentation for more information about Section activeness
    # Handle active sections
    sections_new = article.sections_hash.map do |name, source_copy|
      article.sections.for_name(name).create_or_update!(name: name, source_copy: source_copy, active: true)
    end

    # Inactivate sections which are not in the current sections_hash of the Article
    article.sections.where(id: (article.sections.pluck(:id) - sections_new.map(&:id))).update_all(active: false)

    # Re-import necessary sections
    # No need to re-import section that are not active. if they ever become active again, they would be reimported
    # since `active` attribute is being watched.
    article.import_batch.jobs do
      sections_new.each do |section|
        if force_import_sections || %w(source_copy active).any? {|field| section.previous_changes.include?(field)} # inactivating wouldn't trigger this, since this is called on only active sections.
          SectionImporter.perform_once(section.id)
        end
      end
    end
  end

  include SidekiqLocking

  # Contains hooks run by Sidekiq upon completion of an Article import batch.

  class Finisher

    # Run by Sidekiq after an Article's import batch finishes successfully.
    # Unsets the {Article}'s `loading` flag.
    # Recalculates readiness for the {Key Keys} in the Article, and for the {Article} itself.

    def on_success(_status, options)
      article = Article.find(options['article_id'])

      # finish loading
      article.update_import_finishing_fields!

      # the readiness hooks were all disabled, so now we need to go through and calculate readiness.
      # another reason to refresh is that section/article information for article translations may be out of date
      Key.batch_recalculate_ready!(article)
      ArticleRecalculator.new.perform(article.id)

      # Keys are refreshed as part of `Key.batch_recalculate_ready!`.
      # Translations need to be refreshed in case section data (such as `activeness`) changed in
      # the last re-import. CommitKeyCreator takes care of refreshing Translations in a Commit during a Commit import.
      Translation.batch_refresh_elastic_search(article)
    end
  end
end
