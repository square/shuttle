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

class CreateDailyMetrics < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE daily_metrics (
        id SERIAL PRIMARY KEY,
        metadata text,
        date date NOT NULL,
        created_at timestamp without time zone,
        updated_at timestamp without time zone
      )
    SQL

    execute "CREATE UNIQUE INDEX daily_metrics_date ON daily_metrics USING btree (date)"
  end

  def down
    drop_table :daily_metrics
  end
end
