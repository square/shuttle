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
    module SourceGlossaryEntries

      class Edit < Views::Layouts::Application
        needs :source_entry

        protected

        def body_content
          article(class: 'container') do
            page_header "Edit Source Glossary Entry"
            div(class: 'row-fluid') do
              div(class: 'span6') { edit_side }
            end
          end
        end

        private

        def edit_side
          h3 @source_entry.source_locale.name

          form_for @source_entry, url: glossary_source_url(@source_entry) do |f|
            div class: 'control-group' do
              label 'English', class: 'control-label', for: 'inputEnglish'
              div class: 'controls' do
                f.text_field :source_copy, placeholder: 'English', autocomplete: 'off', required: 'true', value: @source_entry.source_copy
              end
            end

            div class: 'control-group' do
              label 'Context', class: 'control-label'
              div class: 'controls' do
                f.text_field :context, placeholder: 'Context', autocomplete: 'off', value: @source_entry.context
              end
            end

            div class: 'control-group' do
              label 'Notes', class: 'control-label'
              div class: 'controls' do
                f.text_area :notes, placeholder: 'Notes', autocomplete: 'off', value: @source_entry.notes
              end
            end

          #   label(for: 'blank_string', class: 'checkbox') do
          #     check_box_tag 'blank_string', '1', (@translation.translated? && @translation.copy.blank? ? 'checked' : nil)
          #     text " The translation for this copy is a blank string"
          #   end

            div class: 'controls', style: 'height: 40px;' do
              f.submit "Update Entry", class: 'btn btn-primary', style: 'float: right; width: 200px;'
            end

            # TODO: Add a modal in the future to CONFIRM destroy.
            if current_user.try!(:admin?)
              div class: 'controls', style: 'height: 40px;' do
                # TODO: LOOK AT LATER.
              link_to "Destroy Entry", glossary_source_url(@source_entry), :method => :delete, class: 'btn btn-danger', style: 'float: right; width: 200px;'
              end  
            end
            
          end

          dl do
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
