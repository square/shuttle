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
  module Home
    class Glossary < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          page_header do
            h1 "Glossary", style: 'display: inline;'
            button class: 'btn page-header-btn', :'data-target'=>'#settings-modal', :'data-toggle'=>'modal' do
              i class: 'icon-cog'
            end
            button "Add New Term", id: 'add-new-term', class: "btn btn-success page-header-btn", :'data-target'=>'#add-term-modal', :'data-toggle'=>'modal'
          end

          div class: 'row', id: 'alphabet-bar' do 
            span class: 'span12' do
              ul class: 'nav' do
                  "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").each do |letter|
                    li do
                      a letter, href: "#glossary-table-" + letter
                    end
                  end
              end
            end
          end
          div class: "row", id: 'glossary' do 
            span class: 'span12' do
              table class: 'table table-condensed', id: 'glossary-table' 
            end
          end

        end

        div id: 'settings-modal', class: 'modal hide fade', tabindex: '-1', role: 'dialog', :'aria-labelledby' => 'myModalLabel', :'aria-hidden' => 'true' do
          form id: 'settings-form', class: 'form-horizontal', style: 'margin-bottom: 0px' do
            div class: 'modal-header' do
              button "×", type: 'button', class: 'close', :'data-dismiss' => 'modal', :'aria-hidden'=>'true'
              h3 "Edit Settings"
            end
            div class: 'modal-body' do

              div class: 'control-group' do
                label 'Source', class: 'control-label', for: 'selectSource'
                div class: 'controls' do
                  select id: 'selectSource' do
                    option "en"
                    option "fr"
                    option "sp"
                    option "gb"
                    option "jp"
                  end 
                end
              end

              div class: 'control-group' do
                label 'Target Languages', class: 'control-label', for: 'inputEnglish'
                div class: 'controls' do
                  div class: 'checkbox' do
                    label do
                      input type: 'checkbox', value: '0'
                      text "French"
                    end
                  end
                end
              end

            end
            div class: 'modal-footer' do
              a 'Cancel', href: '#', class: 'btn', :'data-dismiss' => 'modal'
              input type: 'submit', value: 'Save', class: 'btn btn-primary'
            end
          end
        end

        div id: 'add-term-modal', class: 'modal hide fade', tabindex: '-1', role: 'dialog', :'aria-labelledby' => 'myModalLabel', :'aria-hidden' => 'true' do
          form id: 'add-term-form', class: 'form-horizontal', style: 'margin-bottom: 0px' do
            div class: 'modal-header' do
              button "×", type: 'button', class: 'close', :'data-dismiss' => 'modal', :'aria-hidden'=>'true'
              h3 "Add New Term"
            end

            div class: 'modal-body' do

              div class: 'control-group' do
                label 'English', class: 'control-label', for: 'inputEnglish'
                div class: 'controls' do
                  input type: 'text', id: 'add-term-inputEnglish', placeholder: 'English', autocomplete: 'off', required: 'true'
                end
              end

              div class: 'control-group' do
                label 'Context', class: 'control-label', for: 'inputContext'
                div class: 'controls' do
                  input type: 'text', id: 'add-term-inputContext', placeholder: 'Context', autocomplete: 'off'
                end
              end

              div class: 'control-group' do
                label 'Notes', class: 'control-label', for: 'textAreaNotes'
                div class: 'controls' do
                  textarea rows: "3", id: 'add-term-textAreaNotes', placeholder: 'Notes', autocomplete: 'off'
                end
              end

              div class: 'control-group' do
                label 'Due Date', class: 'control-label', for: 'inputDueDate'
                div class: 'controls' do
                  input type: 'text', id: 'add-term-inputDueDate', autocomplete: 'off'
                end
              end
            end

            div class: 'modal-footer' do
              a 'Cancel', href: '#', class: 'btn', :'data-dismiss' => 'modal'
              input type: 'submit', value: 'Submit', class: 'btn btn-primary'
            end
          end 
        end
      end

      def active_tab() 'glossary' 
      end
    end
  end
end
