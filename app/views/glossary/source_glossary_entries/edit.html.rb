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
          confirm_delete_modal
        end

        private

        def edit_side
          h3 @source_entry.source_locale.name

          form_for @source_entry, url: glossary_source_url(@source_entry) do |f|
            div class: 'control-group' do
              label 'English', class: 'control-label'
              div class: 'controls' do
                f.text_field :source_copy, placeholder: 'English', autocomplete: 'off', required: 'true'
              end
            end

            div class: 'control-group' do
              label 'Context', class: 'control-label'
              div class: 'controls' do
                f.text_field :context, placeholder: 'Context', autocomplete: 'off'
              end
            end

            div class: 'control-group' do
              label 'Notes', class: 'control-label'
              div class: 'controls' do
                f.text_area :notes, placeholder: 'Notes', autocomplete: 'off'
              end
            end

            div class: 'control-group' do
              label 'Due Date', class: 'control-label'
              div class: 'controls' do
                f.text_field :due_date, autocomplete: 'off', id: 'edit-entry-inputDueDate'
              end
            end

            div class: 'controls', style: 'height: 40px;' do
              f.submit "Update Entry", id: 'btn-update-entry', class: 'btn btn-primary'
            end

            if current_user.try!(:admin?)
              div class: 'controls', style: 'height: 40px;' do
                button "Delete Entry", id: 'btn-confirm-delete', class: "btn btn-danger", :'data-target'=>'#confirm-delete-modal', :'data-toggle'=>'modal'
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

        def confirm_delete_modal
          div id: 'confirm-delete-modal', class: 'modal hide fade', tabindex: '-1', role: 'dialog', :'aria-labelledby' => 'myModalLabel', :'aria-hidden' => 'true' do
            div class: 'modal-header' do
              button "×", type: 'button', class: 'close', :'data-dismiss' => 'modal', :'aria-hidden'=>'true'
              h3 "Confirm Delete"
            end

            div class: 'modal-body' do
              p "Are you sure you want to delete this entry?"
            end

            div class: 'modal-footer' do
              a 'Cancel', href: '#', class: 'btn', :'data-dismiss' => 'modal'
              link_to "Delete Entry", glossary_source_url(@source_entry), :method => :delete, id: 'btn-destroy-entry', class: 'btn btn-danger'
            end
          end 
        end 

        def active_tab() 'glossary' 
        end
      end
      
    end
  end
end
