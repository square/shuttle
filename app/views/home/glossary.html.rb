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
          page_header 'Glossary'

          div(id: 'glossary-header', class: "row") do
            span(class: "span6") do
              # only show this if they should be able to see it.
              form(id: 'new-glossary-entry') do
                input(type: 'text', name: "source_copy", placeholder: 'new glossary entry')
              end
            end
            span(class: "span6") do
              div(style: 'float: right;') do
                form(id: 'locale') do
                  input type: 'text', name: 'locale', class: 'locale-field', placeholder: 'type a locale here', id: 'locale-field'
                  i class: 'icon-refresh spinning', id: 'spinner', style: 'display: none'
                end
              end
            end
          end

          div(id: 'glossary')
        end
      end

      def active_tab() 'glossary' end
    end
  end
end
