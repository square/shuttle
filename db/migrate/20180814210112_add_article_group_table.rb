class AddArticleGroupTable < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE article_groups (
        id SERIAL PRIMARY KEY,
        group_id integer NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        article_id integer NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
        index_in_group integer NOT NULL,
        created_at timestamp without time zone NOT NULL,
        updated_at timestamp without time zone NOT NULL
      )
    SQL

    add_index(:article_groups, [:group_id])
    add_index(:article_groups, [:article_id])
  end

  def down
    drop_table :article_groups
  end
end
