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

module Views
  module Glossary
    module LocaleGlossaryEntries

      class Edit < Views::Layouts::Application
        needs :source_entry, :locale_entry

        protected

        def body_content
          article(class: 'container') do
            page_header "Translate Locale Glossary Entry"
            div(class: 'row-fluid') do
              div(class: 'span6') { edit_side }
              div(class: 'span6') { information_side }
            end
          end
        end

        private

        def edit_side
          h3 @locale_entry.locale.name

          form_for @locale_entry, url: glossary_source_locale_url(@source_entry, @locale_entry), html: {} do |f|
            div class: 'control-group' do
              label @locale_entry.locale.name, class: 'control-label'
              div class: 'controls' do
                f.text_field :copy, id: 'locale-copy', placeholder: @locale_entry.locale.name, autocomplete: 'off', value: @locale_entry.copy
              end
            end

            div class: 'control-group' do
              label 'Notes', class: 'control-label'
              div class: 'controls' do
                f.text_area :notes, placeholder: 'Notes', autocomplete: 'off', value: @locale_entry.notes
              end
            end

          #   label(for: 'blank_string', class: 'checkbox') do
          #     check_box_tag 'blank_string', '1', (@translation.translated? && @translation.copy.blank? ? 'checked' : nil)
          #     text " The translation for this copy is a blank string"
          #   end

            div class: 'controls', style: 'height: 40px;' do
              f.submit class: 'btn btn-primary', style: 'float: right;'
            end
          end

          dl do
            if @locale_entry.translator
              dt "Translator"
              dd @locale_entry.translator.name
            end
            if @locale_entry.reviewer
              dt "Reviewer"
              dd @locale_entry.reviewer.name
            end

            dt "Created at:"
            dd @locale_entry.created_at
            dt "Last updated at:"
            dd @locale_entry.updated_at
          end
        end

        def information_side
          h3 @source_entry.source_locale.name

          div class: 'control-group', style: 'height: 40px' do
            label @source_entry.source_locale.name, class: 'control-label'
            div class: 'controls' do
              div class: 'input-append input-block-level' do
                input type: 'text', disabled: 'disabled', value: @source_entry.source_copy
                a "Copy to #{@locale_entry.locale.name}", id: 'copy-source-button', class: 'btn add-on'
              end
            end
          end

          div class: 'control-group' do
            label 'Context', class: 'control-label'
            div class: 'controls' do
              input type: 'text', disabled: 'disabled', value: @source_entry.context
            end
          end
          
          div class: 'control-group' do
            label 'Notes', class: 'control-label'
            div class: 'controls' do
              textarea @source_entry.notes, disabled: 'disabled'
            end
          end

          dl do
            if @source_entry.due_date
              dt "Due at:"
              dd @source_entry.due_date
            end
            dt "Created at:"
            dd @source_entry.created_at
            dt "Last updated at:"
            dd @source_entry.updated_at
          end
        end

        def active_tab() 'glossary' 
        end
      end

    end
  end
end
