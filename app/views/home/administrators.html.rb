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
  module Home
    class Administrators < Views::Layouts::Application
      protected

      def body_content
        article(class: 'container') do
          page_header "Projects in Shuttle"
          div id: 'projects', class: 'status-panel'

          if current_user.monitor?
            button "Add Project", href: new_project_url, class: 'btn btn-default'
          end
        end
      end

      def active_tab() 'admin' end
    end
  end
end
