# encoding: utf-8

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

# encoding: utf-8

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module Translations
    class Show < Views::Layouts::Application
      needs :translation

      protected

      def body_content
        article(class: 'container') do
          page_header "Translation #{@translation.id}"

          source_info
          copy_info
          status_info
        end
      end

      private

      def source_info
        h2 "Source Information"

        h6 "Key"
        pre @translation.key.original_key

        if @translation.key.context.present?
          h6 "Context"
          pre @translation.key.context
        end

        dl do
          if @translation.key.source.present?
            dt "Source"
            dd @translation.key.source
          end

          if @translation.key.importer.present?
            dt "Importer"
            dd Importer::Base.find_by_ident(@translation.key.importer).human_name
          end

          if @translation.key.fencers.present?
            dt "Fencers"
            dd @translation.key.fencers.map { |f| I18n.t("fencer.#{f}") }.to_sentence
          end
        end
      end

      def copy_info
        h2 "Copy Information"

        h5 "— translated from —"
        h6 @translation.source_locale.name
        pre @translation.source_copy

        h5 "— to —"
        h6 @translation.locale.name
        if @translation.copy
          pre(@translation.copy)
        else
          p "(untranslated)", class: 'muted'
        end
      end

      def status_info
        h2 "Status Information"

        dl do
          if @translation.translator
            dt "Translated by"
            dd @translation.translator.name
          end

          if @translation.reviewer
            dt "Reviewed by"
            dd @translation.reviewer.name
          end

          dt "Status"
          dd(
              if @translation.approved.nil?
                @translation.translated? ? "Pending Approval" : "Pending Translation"
              elsif @translation.approved == false
                "Rejected"
              elsif @translation.approved == true
                "Approved"
              end
          )
        end
      end
    end
  end
end
