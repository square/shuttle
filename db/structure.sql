--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: blobs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE blobs (
    project_id integer NOT NULL,
    sha_raw bytea NOT NULL,
    metadata text
);


--
-- Name: commits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE commits (
    id integer NOT NULL,
    project_id integer NOT NULL,
    revision_raw bytea NOT NULL,
    message character varying(256) NOT NULL,
    committed_at timestamp without time zone NOT NULL,
    ready boolean DEFAULT false NOT NULL,
    loading boolean DEFAULT false NOT NULL,
    metadata text,
    created_at timestamp without time zone,
    due_date date,
    priority integer,
    user_id integer,
    completed_at timestamp without time zone,
    exported boolean DEFAULT false NOT NULL,
    CONSTRAINT commits_message_check CHECK ((char_length((message)::text) > 0)),
    CONSTRAINT commits_priority_check CHECK (((priority >= 0) AND (priority <= 3)))
);


--
-- Name: commits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE commits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE commits_id_seq OWNED BY commits.id;


--
-- Name: commits_keys; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE commits_keys (
    commit_id integer NOT NULL,
    key_id integer NOT NULL
);


--
-- Name: glossary_entries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE glossary_entries (
    id integer NOT NULL,
    translator_id integer,
    reviewer_id integer,
    metadata text,
    source_rfc5646_locale character varying(15) NOT NULL,
    rfc5646_locale character varying(15) NOT NULL,
    translated boolean DEFAULT false NOT NULL,
    approved boolean,
    key_sha_raw bytea,
    source_copy_sha_raw bytea,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: glossary_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE glossary_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: glossary_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE glossary_entries_id_seq OWNED BY glossary_entries.id;


--
-- Name: keys; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE keys (
    id integer NOT NULL,
    metadata text,
    project_id integer NOT NULL,
    key_sha_raw bytea NOT NULL,
    source_copy_sha_raw bytea NOT NULL,
    ready boolean DEFAULT true NOT NULL
);


--
-- Name: keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE keys_id_seq OWNED BY keys.id;


--
-- Name: locale_glossary_entries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE locale_glossary_entries (
    id integer NOT NULL,
    translator_id integer,
    reviewer_id integer,
    source_glossary_entry_id integer,
    metadata text,
    rfc5646_locale character varying(15) NOT NULL,
    translated boolean DEFAULT false NOT NULL,
    approved boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: locale_glossary_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE locale_glossary_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locale_glossary_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE locale_glossary_entries_id_seq OWNED BY locale_glossary_entries.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE projects (
    id integer NOT NULL,
    name character varying(256) NOT NULL,
    metadata text,
    repository_url character varying(256) NOT NULL,
    api_key character(36) NOT NULL,
    created_at timestamp without time zone,
    CONSTRAINT projects_name_check CHECK ((char_length((name)::text) > 0)),
    CONSTRAINT projects_repository_url_check CHECK ((char_length((repository_url)::text) > 0))
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: slugs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE slugs (
    id integer NOT NULL,
    sluggable_id integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    slug character varying(126) NOT NULL,
    scope character varying(126),
    created_at timestamp without time zone NOT NULL,
    sluggable_type character varying(126) NOT NULL,
    CONSTRAINT slugs_slug_check CHECK ((char_length((slug)::text) > 0))
);


--
-- Name: slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE slugs_id_seq OWNED BY slugs.id;


--
-- Name: source_glossary_entries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE source_glossary_entries (
    id integer NOT NULL,
    metadata text,
    source_rfc5646_locale character varying(15) DEFAULT 'en'::character varying NOT NULL,
    source_copy_sha_raw bytea,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: source_glossary_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE source_glossary_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_glossary_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE source_glossary_entries_id_seq OWNED BY source_glossary_entries.id;


--
-- Name: translation_changes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE translation_changes (
    id integer NOT NULL,
    translation_id integer NOT NULL,
    metadata text,
    created_at timestamp without time zone,
    user_id integer
);


--
-- Name: translation_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE translation_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE translation_changes_id_seq OWNED BY translation_changes.id;


--
-- Name: translation_units; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE translation_units (
    id integer NOT NULL,
    source_copy text,
    copy text,
    source_copy_sha_raw bytea NOT NULL,
    copy_sha_raw bytea NOT NULL,
    source_rfc5646_locale character varying(15) NOT NULL,
    rfc5646_locale character varying(15) NOT NULL,
    created_at timestamp without time zone
);


--
-- Name: translation_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE translation_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE translation_units_id_seq OWNED BY translation_units.id;


--
-- Name: translations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE translations (
    id integer NOT NULL,
    metadata text,
    key_id integer NOT NULL,
    translator_id integer,
    reviewer_id integer,
    source_rfc5646_locale character varying(15) NOT NULL,
    rfc5646_locale character varying(15) NOT NULL,
    translated boolean DEFAULT false NOT NULL,
    approved boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    words_count integer DEFAULT 0 NOT NULL
);


--
-- Name: translations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE translations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE translations_id_seq OWNED BY translations.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
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
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits ALTER COLUMN id SET DEFAULT nextval('commits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY glossary_entries ALTER COLUMN id SET DEFAULT nextval('glossary_entries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY keys ALTER COLUMN id SET DEFAULT nextval('keys_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries ALTER COLUMN id SET DEFAULT nextval('locale_glossary_entries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY slugs ALTER COLUMN id SET DEFAULT nextval('slugs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY source_glossary_entries ALTER COLUMN id SET DEFAULT nextval('source_glossary_entries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes ALTER COLUMN id SET DEFAULT nextval('translation_changes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_units ALTER COLUMN id SET DEFAULT nextval('translation_units_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations ALTER COLUMN id SET DEFAULT nextval('translations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY blobs
    ADD CONSTRAINT blobs_pkey PRIMARY KEY (project_id, sha_raw);


--
-- Name: commits_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY commits_keys
    ADD CONSTRAINT commits_keys_pkey PRIMARY KEY (commit_id, key_id);


--
-- Name: commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY commits
    ADD CONSTRAINT commits_pkey PRIMARY KEY (id);


--
-- Name: glossary_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY glossary_entries
    ADD CONSTRAINT glossary_entries_pkey PRIMARY KEY (id);


--
-- Name: keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY keys
    ADD CONSTRAINT keys_pkey PRIMARY KEY (id);


--
-- Name: locale_glossary_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_pkey PRIMARY KEY (id);


--
-- Name: projects_api_key_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_api_key_key UNIQUE (api_key);


--
-- Name: projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY slugs
    ADD CONSTRAINT slugs_pkey PRIMARY KEY (id);


--
-- Name: source_glossary_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY source_glossary_entries
    ADD CONSTRAINT source_glossary_entries_pkey PRIMARY KEY (id);


--
-- Name: translation_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY translation_changes
    ADD CONSTRAINT translation_changes_pkey PRIMARY KEY (id);


--
-- Name: translation_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY translation_units
    ADD CONSTRAINT translation_units_pkey PRIMARY KEY (id);


--
-- Name: translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: commits_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX commits_date ON commits USING btree (project_id, committed_at);


--
-- Name: commits_keys_key_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX commits_keys_key_id ON commits_keys USING btree (key_id);


--
-- Name: commits_priority; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX commits_priority ON commits USING btree (priority, due_date);


--
-- Name: commits_ready_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX commits_ready_date ON commits USING btree (project_id, ready, committed_at);


--
-- Name: commits_rev; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX commits_rev ON commits USING btree (project_id, revision_raw);


--
-- Name: glossary_source_copy_sha; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX glossary_source_copy_sha ON glossary_entries USING btree (source_copy_sha_raw, rfc5646_locale);


--
-- Name: keys_unique; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX keys_unique ON keys USING btree (project_id, key_sha_raw, source_copy_sha_raw);


--
-- Name: projects_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX projects_name ON projects USING btree (lower((name)::text));


--
-- Name: projects_repo; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX projects_repo ON projects USING btree (lower((repository_url)::text));


--
-- Name: slugs_for_record; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX slugs_for_record ON slugs USING btree (sluggable_type, sluggable_id, active);


--
-- Name: slugs_unique; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX slugs_unique ON slugs USING btree (sluggable_type, lower((scope)::text), lower((slug)::text));


--
-- Name: translation_units_unique; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX translation_units_unique ON translation_units USING btree (source_copy_sha_raw, copy_sha_raw, source_rfc5646_locale, rfc5646_locale);


--
-- Name: translations_by_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX translations_by_key ON translations USING btree (key_id, rfc5646_locale);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: users_email; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX users_email ON users USING btree (email);


--
-- Name: users_reset_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX users_reset_token ON users USING btree (reset_password_token);


--
-- Name: users_unlock_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX users_unlock_token ON users USING btree (unlock_token);


--
-- Name: blobs_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs
    ADD CONSTRAINT blobs_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: commits_keys_commit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits_keys
    ADD CONSTRAINT commits_keys_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id) ON DELETE CASCADE;


--
-- Name: commits_keys_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits_keys
    ADD CONSTRAINT commits_keys_key_id_fkey FOREIGN KEY (key_id) REFERENCES keys(id) ON DELETE CASCADE;


--
-- Name: commits_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits
    ADD CONSTRAINT commits_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: commits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits
    ADD CONSTRAINT commits_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: glossary_entries_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY glossary_entries
    ADD CONSTRAINT glossary_entries_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: glossary_entries_translator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY glossary_entries
    ADD CONSTRAINT glossary_entries_translator_id_fkey FOREIGN KEY (translator_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: keys_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY keys
    ADD CONSTRAINT keys_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: locale_glossary_entries_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: locale_glossary_entries_source_glossary_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_source_glossary_entry_id_fkey FOREIGN KEY (source_glossary_entry_id) REFERENCES source_glossary_entries(id) ON DELETE CASCADE;


--
-- Name: locale_glossary_entries_translator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_translator_id_fkey FOREIGN KEY (translator_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: translation_changes_translation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes
    ADD CONSTRAINT translation_changes_translation_id_fkey FOREIGN KEY (translation_id) REFERENCES translations(id) ON DELETE CASCADE;


--
-- Name: translation_changes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes
    ADD CONSTRAINT translation_changes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: translations_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_key_id_fkey FOREIGN KEY (key_id) REFERENCES keys(id) ON DELETE CASCADE;


--
-- Name: translations_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: translations_translator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_translator_id_fkey FOREIGN KEY (translator_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('20130605211557');

INSERT INTO schema_migrations (version) VALUES ('20130611035759');

INSERT INTO schema_migrations (version) VALUES ('20130612201509');

INSERT INTO schema_migrations (version) VALUES ('20130612202700');

INSERT INTO schema_migrations (version) VALUES ('20130612203159');

INSERT INTO schema_migrations (version) VALUES ('20130612204200');

INSERT INTO schema_migrations (version) VALUES ('20130612204433');

INSERT INTO schema_migrations (version) VALUES ('20130612204434');

INSERT INTO schema_migrations (version) VALUES ('20130612213313');

INSERT INTO schema_migrations (version) VALUES ('20130614052719');

INSERT INTO schema_migrations (version) VALUES ('20130619195215');

INSERT INTO schema_migrations (version) VALUES ('20130801190316');

INSERT INTO schema_migrations (version) VALUES ('20130807224704');

INSERT INTO schema_migrations (version) VALUES ('20130821011600');

INSERT INTO schema_migrations (version) VALUES ('20130821011614');

INSERT INTO schema_migrations (version) VALUES ('20131008220117');

INSERT INTO schema_migrations (version) VALUES ('20131111213136');

INSERT INTO schema_migrations (version) VALUES ('20131116042827');

INSERT INTO schema_migrations (version) VALUES ('20131204020552');
