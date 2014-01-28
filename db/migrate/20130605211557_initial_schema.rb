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

class InitialSchema < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE projects (
          id SERIAL PRIMARY KEY,
          name character varying(256) NOT NULL,
          metadata text,
          repository_url character varying(256) NOT NULL,
          api_key character(36) NOT NULL UNIQUE,
          created_at timestamp without time zone,
          CONSTRAINT projects_name_check CHECK ((char_length((name)::text) > 0)),
          CONSTRAINT projects_repository_url_check CHECK ((char_length((repository_url)::text) > 0))
      )
    SQL

    execute <<-SQL
      CREATE TABLE blobs (
          project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          sha_raw bytea NOT NULL,
          metadata text,
          PRIMARY KEY (project_id, sha_raw)
      )
    SQL

    execute <<-SQL
      CREATE TABLE commits (
          id SERIAL PRIMARY KEY,
          project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          revision_raw bytea NOT NULL,
          message character varying(256) NOT NULL,
          committed_at timestamp without time zone NOT NULL,
          ready boolean DEFAULT true NOT NULL,
          translations_done integer DEFAULT 0 NOT NULL,
          translations_total integer DEFAULT 0 NOT NULL,
          strings_total integer DEFAULT 0 NOT NULL,
          loading boolean DEFAULT false NOT NULL,
          CONSTRAINT commits_message_check CHECK ((char_length((message)::text) > 0))
      )
    SQL

    execute <<-SQL
      CREATE TABLE keys (
          id SERIAL PRIMARY KEY,
          metadata text,
          project_id integer NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          key_sha_raw bytea NOT NULL,
          source_copy_sha_raw bytea NOT NULL,
          searchable_key tsvector,
          key_prefix character(10),
          ready boolean DEFAULT true NOT NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE commits_keys (
          commit_id integer NOT NULL REFERENCES commits(id) ON DELETE CASCADE,
          key_id integer NOT NULL REFERENCES keys(id) ON DELETE CASCADE,
          PRIMARY KEY (commit_id, key_id)
      )
    SQL

    execute <<-SQL
      CREATE TABLE users (
          id SERIAL PRIMARY KEY,
          email character varying(255) NOT NULL,
          metadata text,
          reset_password_token character varying(255),
          sign_in_count integer DEFAULT 0 NOT NULL,
          failed_attempts integer DEFAULT 0 NOT NULL,
          unlock_token character varying(255),
          role character varying(50) DEFAULT NULL::character varying,
          created_at timestamp without time zone,
          updated_at timestamp without time zone,
          CONSTRAINT users_email_check CHECK ((char_length((email)::text) > 0)),
          CONSTRAINT users_failed_attempts_check CHECK ((failed_attempts >= 0)),
          CONSTRAINT users_sign_in_count_check CHECK ((sign_in_count >= 0))
      )
    SQL

    execute <<-SQL
      CREATE TABLE glossary_entries (
          id SERIAL PRIMARY KEY,
          translator_id integer REFERENCES users(id) ON DELETE SET NULL,
          reviewer_id integer REFERENCES users(id) ON DELETE SET NULL,
          metadata text,
          searchable_copy tsvector,
          searchable_source_copy tsvector,
          source_rfc5646_locale character varying(15) NOT NULL,
          rfc5646_locale character varying(15) NOT NULL,
          translated boolean DEFAULT false NOT NULL,
          approved boolean,
          key_sha_raw bytea,
          source_copy_sha_raw bytea,
          created_at timestamp without time zone,
          updated_at timestamp without time zone,
          source_copy_prefix character(5) NOT NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE slugs (
          id SERIAL PRIMARY KEY,
          sluggable_id integer NOT NULL,
          active boolean DEFAULT true NOT NULL,
          slug character varying(126) NOT NULL,
          scope character varying(126),
          created_at timestamp without time zone NOT NULL,
          sluggable_type character varying(126) NOT NULL,
          CONSTRAINT slugs_slug_check CHECK ((char_length((slug)::text) > 0))
      )
    SQL

    execute <<-SQL
      CREATE TABLE translation_units (
          id SERIAL PRIMARY KEY,
          source_copy text,
          copy text,
          source_copy_sha_raw bytea NOT NULL,
          copy_sha_raw bytea NOT NULL,
          searchable_source_copy tsvector,
          searchable_copy tsvector,
          source_rfc5646_locale character varying(15) NOT NULL,
          rfc5646_locale character varying(15) NOT NULL,
          created_at timestamp without time zone
      )
    SQL

    execute <<-SQL
      CREATE TABLE translations (
          id SERIAL PRIMARY KEY,
          metadata text,
          key_id integer NOT NULL REFERENCES keys(id) ON DELETE CASCADE,
          translator_id integer REFERENCES users(id) ON DELETE SET NULL,
          reviewer_id integer REFERENCES users(id) ON DELETE SET NULL,
          source_rfc5646_locale character varying(15) NOT NULL,
          rfc5646_locale character varying(15) NOT NULL,
          searchable_copy tsvector,
          searchable_source_copy tsvector,
          translated boolean DEFAULT false NOT NULL,
          approved boolean,
          created_at timestamp without time zone,
          updated_at timestamp without time zone
      )
    SQL

    execute "CREATE INDEX commits_date ON commits USING btree (project_id, committed_at)"
    execute "CREATE INDEX commits_ready_date ON commits USING btree (project_id, ready, committed_at)"
    execute "CREATE UNIQUE INDEX commits_rev ON commits USING btree (project_id, revision_raw)"

    execute "CREATE INDEX glossary_entries_sorted ON glossary_entries USING btree (rfc5646_locale, source_copy_prefix)"
    execute "CREATE UNIQUE INDEX glossary_source_copy_sha ON glossary_entries USING btree (source_copy_sha_raw, rfc5646_locale)"

    execute "CREATE INDEX keys_search ON keys USING gin (searchable_key)"
    execute "CREATE INDEX keys_sorted ON keys USING btree (project_id, key_prefix)"
    execute "CREATE UNIQUE INDEX keys_unique ON keys USING btree (project_id, key_sha_raw, source_copy_sha_raw)"

    execute "CREATE UNIQUE INDEX projects_repo ON projects USING btree (lower((repository_url)::text))"

    execute "CREATE INDEX slugs_for_record ON slugs USING btree (sluggable_type, sluggable_id, active)"
    execute "CREATE UNIQUE INDEX slugs_unique ON slugs USING btree (sluggable_type, lower((scope)::text), lower((slug)::text))"

    execute "CREATE INDEX translation_units_search ON translation_units USING gin (searchable_copy)"
    execute "CREATE INDEX translation_units_source_search ON translation_units USING gin (searchable_source_copy)"

    execute "CREATE UNIQUE INDEX translation_units_unique ON translation_units USING btree (source_copy_sha_raw, copy_sha_raw, source_rfc5646_locale, rfc5646_locale)"
    execute "CREATE UNIQUE INDEX translations_by_key ON translations USING btree (key_id, rfc5646_locale)"

    execute "CREATE UNIQUE INDEX users_email ON users USING btree (email)"
    execute "CREATE UNIQUE INDEX users_reset_token ON users USING btree (reset_password_token)"
    execute "CREATE UNIQUE INDEX users_unlock_token ON users USING btree (unlock_token)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
