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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')
require Rails.root.join('app', 'helpers', 'history.html.rb')

module Views
  module Translations
    class Edit < Views::Layouts::Application
      needs :project, :key, :translation

      include Views::Translations::History

      protected

      def body_content
        article(class: 'container') do
          page_header "Translation #{@translation.id}"
          div(class: 'row-fluid') do
            div(class: 'span6') { translation_side }
            div(class: 'span6') { information_side }
          end
        end
      end

      private

      def translation_side
        h3 @translation.locale.name

        form_for @translation, url: project_key_translation_url(@project, @key, @translation), html: {id: 'large-translation'} do |f|

          f.text_area :copy

          label(for: 'blank_string', class: 'checkbox') do
            check_box_tag 'blank_string', '1', (@translation.translated? && @translation.copy.blank? ? 'checked' : nil)
            text " The translation for this copy is a blank string"
          end

          div(class: 'form-actions') do
            f.submit class: 'btn btn-primary'
          end
        end
        history_info
      end

      def information_side
        h3 @translation.source_locale.name

        pre @translation.source_copy, class: 'well', id: 'source-copy'
        p { a "Copy to #{@translation.locale.name}", href: '#', id: 'copy-button', class: 'btn btn-small' }

        dl do
          dt "Key"
          dd @translation.key.original_key
          dt "Context"
          dd(@translation.key.context || "none")
          dt "Importer"
          dd @translation.key.importer_name
          dt "Fencers"
          dd @translation.key.fencers.map { |f| I18n.t("fencer.#{f}") }.to_sentence
          dt "Source"
          dd @translation.key.source
          if @translation.translator
            dt "Translator"
            dd @translation.translator.name
          end
          if @translation.reviewer
            dt "Reviewer"
            dd @translation.reviewer.name
          end
        end
      end
    end
  end
end
