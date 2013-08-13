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
  module Projects
    class Index < Views::Layouts::Application
      needs :projects

      protected

      def body_content
        article(class: 'container') do
          page_header "Projects"
          project_list
          add_project
        end
      end

      def active_tab() 'projects' end

      private

      def project_list
        @projects.each do |project|
          p do
            a(href: edit_project_url(project)) do
              i class: 'icon-edit'
            end
            text ' '
            strong project.name
          end
        end
      end

      def add_project
        p do
          button_to "Add Project", new_project_url, class: 'btn'
        end
      end
    end
  end
end
