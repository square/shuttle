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

class CreateLocaleAssociations < ActiveRecord::Migration
  def change
    create_table :locale_associations do |t|
      t.string :source_rfc5646_locale, null: false
      t.string :target_rfc5646_locale, null: false
      t.boolean :checked,              null: false, default: false
      t.boolean :uncheckable,          null: false, default: true

      t.timestamps
    end
  end
end
