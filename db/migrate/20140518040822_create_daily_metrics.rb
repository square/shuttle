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
