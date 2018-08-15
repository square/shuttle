class AddGroupTable < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE groups (
        id SERIAL PRIMARY KEY,
        project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        name text NOT NULL,
        description text,
        ready boolean DEFAULT false NOT NULL,
        loading boolean DEFAULT false NOT NULL,
        hidden boolean DEFAULT false,
        due_date date,
        priority integer,
        creator_id integer,
        updater_id integer,
        email character varying(255),
        created_via_api boolean DEFAULT true NOT NULL,
        loaded_at timestamp without time zone,
        translated_at timestamp without time zone,
        approved_at timestamp without time zone,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      )
    SQL

    add_index(:groups, [:project_id])
    add_index(:groups, [:name])
  end

  def down
    drop_table :groups
  end
end
