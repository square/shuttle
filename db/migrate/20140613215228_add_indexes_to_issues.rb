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

class AddIndexesToIssues < ActiveRecord::Migration
  def up
    execute "CREATE INDEX issues_translation_status ON issues(translation_id, status)"
    execute "CREATE INDEX issues_translation_status_priority_created_at ON issues(translation_id, status, priority, created_at)"
  end

  def down
    execute "DROP INDEX issues_translation_status"
    execute "DROP INDEX issues_translation_status_priority_created_at"
  end
end
