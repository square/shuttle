--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.5
-- Dumped by pg_dump version 9.6.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

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
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE articles (
    id integer NOT NULL,
    project_id integer NOT NULL,
    name text NOT NULL,
    sections_hash text NOT NULL,
    base_rfc5646_locale character varying(255) NOT NULL,
    targeted_rfc5646_locales text NOT NULL,
    description text,
    email character varying(255),
    import_batch_id character varying(255),
    ready boolean DEFAULT false NOT NULL,
    first_import_requested_at timestamp without time zone,
    last_import_requested_at timestamp without time zone,
    first_import_started_at timestamp without time zone,
    last_import_started_at timestamp without time zone,
    first_import_finished_at timestamp without time zone,
    last_import_finished_at timestamp without time zone,
    first_completed_at timestamp without time zone,
    last_completed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    due_date date,
    priority integer,
    creator_id integer,
    updater_id integer,
    created_via_api boolean DEFAULT true NOT NULL,
    name_sha character varying(64) NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    human_review boolean DEFAULT true NOT NULL
);


--
-- Name: articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE articles_id_seq OWNED BY articles.id;


--
-- Name: blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE blobs (
    project_id integer NOT NULL,
    parsed boolean DEFAULT false NOT NULL,
    errored boolean DEFAULT false NOT NULL,
    id integer NOT NULL,
    path text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    sha character varying(40) NOT NULL,
    path_sha character varying(64) NOT NULL
);


--
-- Name: blobs_commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE blobs_commits (
    commit_id integer NOT NULL,
    id integer NOT NULL,
    blob_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: blobs_commits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE blobs_commits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blobs_commits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE blobs_commits_id_seq OWNED BY blobs_commits.id;


--
-- Name: blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE blobs_id_seq OWNED BY blobs.id;


--
-- Name: blobs_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE blobs_keys (
    key_id integer NOT NULL,
    id integer NOT NULL,
    blob_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: blobs_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE blobs_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blobs_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE blobs_keys_id_seq OWNED BY blobs_keys.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE comments (
    id integer NOT NULL,
    user_id integer,
    issue_id integer NOT NULL,
    content text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--
-- Name: commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE commits (
    id integer NOT NULL,
    project_id integer NOT NULL,
    message character varying(256) NOT NULL,
    committed_at timestamp without time zone NOT NULL,
    ready boolean DEFAULT false NOT NULL,
    loading boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    due_date date,
    priority integer,
    user_id integer,
    completed_at timestamp without time zone,
    exported boolean DEFAULT false NOT NULL,
    loaded_at timestamp without time zone,
    description text,
    author character varying,
    author_email character varying,
    pull_request_url text,
    import_batch_id character varying,
    import_errors text,
    revision character varying(40) NOT NULL,
    fingerprint character varying,
    duplicate boolean DEFAULT false,
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
-- Name: commits_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE commits_keys (
    commit_id integer NOT NULL,
    key_id integer NOT NULL,
    created_at timestamp without time zone
);


--
-- Name: daily_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE daily_metrics (
    id integer NOT NULL,
    date date NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    num_commits_loaded integer,
    num_commits_loaded_per_project text,
    avg_load_time double precision,
    avg_load_time_per_project text,
    num_commits_completed integer,
    num_commits_completed_per_project text,
    num_words_created integer,
    num_words_created_per_language text,
    num_words_completed integer,
    num_words_completed_per_language text
);


--
-- Name: daily_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE daily_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE daily_metrics_id_seq OWNED BY daily_metrics.id;


--
-- Name: issues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE issues (
    id integer NOT NULL,
    user_id integer,
    updater_id integer,
    translation_id integer NOT NULL,
    summary character varying(255),
    description text,
    priority integer,
    kind integer,
    status integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    subscribed_emails text
);


--
-- Name: issues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE issues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: issues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE issues_id_seq OWNED BY issues.id;


--
-- Name: keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE keys (
    id integer NOT NULL,
    project_id integer NOT NULL,
    ready boolean DEFAULT true NOT NULL,
    key text NOT NULL,
    original_key text NOT NULL,
    source_copy text,
    context text,
    importer character varying,
    source text,
    fencers text,
    other_data text,
    section_id integer,
    index_in_section integer,
    is_block_tag boolean DEFAULT false NOT NULL,
    key_sha character varying(64) NOT NULL,
    source_copy_sha character varying(64) NOT NULL,
    hidden_in_search boolean DEFAULT false,
    CONSTRAINT non_negative_index_in_section CHECK ((index_in_section >= 0))
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
-- Name: locale_associations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE locale_associations (
    id integer NOT NULL,
    source_rfc5646_locale character varying NOT NULL,
    target_rfc5646_locale character varying NOT NULL,
    checked boolean DEFAULT false NOT NULL,
    uncheck_disabled boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: locale_associations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE locale_associations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locale_associations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE locale_associations_id_seq OWNED BY locale_associations.id;


--
-- Name: locale_glossary_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE locale_glossary_entries (
    id integer NOT NULL,
    translator_id integer,
    reviewer_id integer,
    source_glossary_entry_id integer,
    rfc5646_locale character varying(15) NOT NULL,
    translated boolean DEFAULT false NOT NULL,
    approved boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    copy text,
    notes text
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
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE projects (
    id integer NOT NULL,
    name character varying(256) NOT NULL,
    repository_url character varying(256),
    created_at timestamp without time zone,
    translations_adder_and_remover_batch_id character varying,
    disable_locale_association_checkbox_settings boolean DEFAULT false NOT NULL,
    base_rfc5646_locale character varying DEFAULT 'en'::character varying NOT NULL,
    targeted_rfc5646_locales text,
    skip_imports text,
    key_exclusions text,
    key_inclusions text,
    key_locale_exclusions text,
    key_locale_inclusions text,
    skip_paths text,
    only_paths text,
    skip_importer_paths text,
    only_importer_paths text,
    default_manifest_format character varying,
    watched_branches text,
    touchdown_branch character varying,
    manifest_directory text,
    manifest_filename character varying,
    github_webhook_url text,
    stash_webhook_url text,
    api_token character(240) NOT NULL,
    CONSTRAINT projects_name_check CHECK ((char_length((name)::text) > 0))
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: screenshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE screenshots (
    commit_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    image_file_name character varying,
    image_content_type character varying,
    image_file_size integer,
    image_updated_at timestamp without time zone,
    id integer NOT NULL
);


--
-- Name: screenshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE screenshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screenshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE screenshots_id_seq OWNED BY screenshots.id;


--
-- Name: sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sections (
    id integer NOT NULL,
    article_id integer NOT NULL,
    name text NOT NULL,
    source_copy text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name_sha character varying(64) NOT NULL,
    source_copy_sha character varying(64) NOT NULL
);


--
-- Name: sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sections_id_seq OWNED BY sections.id;


--
-- Name: slugs; Type: TABLE; Schema: public; Owner: -
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
-- Name: source_glossary_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE source_glossary_entries (
    id integer NOT NULL,
    source_rfc5646_locale character varying(15) DEFAULT 'en'::character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    source_copy text NOT NULL,
    context text,
    notes text,
    due_date date,
    source_copy_sha character varying(64) NOT NULL
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
-- Name: translation_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE translation_changes (
    id integer NOT NULL,
    translation_id integer NOT NULL,
    created_at timestamp without time zone,
    user_id integer,
    diff text
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
-- Name: translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE translations (
    id integer NOT NULL,
    key_id integer NOT NULL,
    translator_id integer,
    reviewer_id integer,
    source_rfc5646_locale character varying(15) NOT NULL,
    rfc5646_locale character varying(15) NOT NULL,
    translated boolean DEFAULT false NOT NULL,
    approved boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    words_count integer DEFAULT 0 NOT NULL,
    source_copy text,
    copy text,
    notes text,
    tm_match numeric,
    translation_date timestamp without time zone,
    review_date timestamp without time zone
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
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    reset_password_token character varying(255),
    sign_in_count integer DEFAULT 0 NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    unlock_token character varying(255),
    role character varying(50) DEFAULT NULL::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    confirmation_token character varying,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    encrypted_password character varying NOT NULL,
    remember_created_at timestamp without time zone,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    locked_at timestamp without time zone,
    reset_password_sent_at timestamp without time zone,
    approved_rfc5646_locales text,
    CONSTRAINT encrypted_password_exists CHECK ((char_length((encrypted_password)::text) > 20)),
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
-- Name: articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY articles ALTER COLUMN id SET DEFAULT nextval('articles_id_seq'::regclass);


--
-- Name: blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs ALTER COLUMN id SET DEFAULT nextval('blobs_id_seq'::regclass);


--
-- Name: blobs_commits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_commits ALTER COLUMN id SET DEFAULT nextval('blobs_commits_id_seq'::regclass);


--
-- Name: blobs_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_keys ALTER COLUMN id SET DEFAULT nextval('blobs_keys_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);


--
-- Name: commits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits ALTER COLUMN id SET DEFAULT nextval('commits_id_seq'::regclass);


--
-- Name: daily_metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY daily_metrics ALTER COLUMN id SET DEFAULT nextval('daily_metrics_id_seq'::regclass);


--
-- Name: issues id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY issues ALTER COLUMN id SET DEFAULT nextval('issues_id_seq'::regclass);


--
-- Name: keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY keys ALTER COLUMN id SET DEFAULT nextval('keys_id_seq'::regclass);


--
-- Name: locale_associations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_associations ALTER COLUMN id SET DEFAULT nextval('locale_associations_id_seq'::regclass);


--
-- Name: locale_glossary_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries ALTER COLUMN id SET DEFAULT nextval('locale_glossary_entries_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: screenshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY screenshots ALTER COLUMN id SET DEFAULT nextval('screenshots_id_seq'::regclass);


--
-- Name: sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sections ALTER COLUMN id SET DEFAULT nextval('sections_id_seq'::regclass);


--
-- Name: slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY slugs ALTER COLUMN id SET DEFAULT nextval('slugs_id_seq'::regclass);


--
-- Name: source_glossary_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY source_glossary_entries ALTER COLUMN id SET DEFAULT nextval('source_glossary_entries_id_seq'::regclass);


--
-- Name: translation_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes ALTER COLUMN id SET DEFAULT nextval('translation_changes_id_seq'::regclass);


--
-- Name: translations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations ALTER COLUMN id SET DEFAULT nextval('translations_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: blobs_commits blobs_commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_commits
    ADD CONSTRAINT blobs_commits_pkey PRIMARY KEY (id);


--
-- Name: blobs_keys blobs_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_keys
    ADD CONSTRAINT blobs_keys_pkey PRIMARY KEY (id);


--
-- Name: blobs blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs
    ADD CONSTRAINT blobs_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: commits commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits
    ADD CONSTRAINT commits_pkey PRIMARY KEY (id);


--
-- Name: daily_metrics daily_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY daily_metrics
    ADD CONSTRAINT daily_metrics_pkey PRIMARY KEY (id);


--
-- Name: issues issues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY issues
    ADD CONSTRAINT issues_pkey PRIMARY KEY (id);


--
-- Name: keys keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY keys
    ADD CONSTRAINT keys_pkey PRIMARY KEY (id);


--
-- Name: locale_associations locale_associations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_associations
    ADD CONSTRAINT locale_associations_pkey PRIMARY KEY (id);


--
-- Name: locale_glossary_entries locale_glossary_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: screenshots screenshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY screenshots
    ADD CONSTRAINT screenshots_pkey PRIMARY KEY (id);


--
-- Name: sections sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sections
    ADD CONSTRAINT sections_pkey PRIMARY KEY (id);


--
-- Name: slugs slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY slugs
    ADD CONSTRAINT slugs_pkey PRIMARY KEY (id);


--
-- Name: source_glossary_entries source_glossary_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY source_glossary_entries
    ADD CONSTRAINT source_glossary_entries_pkey PRIMARY KEY (id);


--
-- Name: translation_changes translation_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes
    ADD CONSTRAINT translation_changes_pkey PRIMARY KEY (id);


--
-- Name: translations translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: comments_issue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_issue ON comments USING btree (issue_id);


--
-- Name: comments_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_user ON comments USING btree (user_id);


--
-- Name: commits_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_date ON commits USING btree (project_id, committed_at);


--
-- Name: commits_keys_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_keys_key_id ON commits_keys USING btree (key_id);


--
-- Name: commits_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_priority ON commits USING btree (priority, due_date);


--
-- Name: commits_ready_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commits_ready_date ON commits USING btree (project_id, ready, committed_at);


--
-- Name: daily_metrics_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX daily_metrics_date ON daily_metrics USING btree (date);


--
-- Name: index_articles_on_name_sha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_name_sha ON articles USING btree (name_sha);


--
-- Name: index_articles_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_project_id ON articles USING btree (project_id);


--
-- Name: index_articles_on_project_id_and_name_sha; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_articles_on_project_id_and_name_sha ON articles USING btree (project_id, name_sha);


--
-- Name: index_articles_on_ready; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_ready ON articles USING btree (ready);


--
-- Name: index_blobs_commits_on_blob_id_and_commit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blobs_commits_on_blob_id_and_commit_id ON blobs_commits USING btree (blob_id, commit_id);


--
-- Name: index_blobs_keys_on_blob_id_and_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blobs_keys_on_blob_id_and_key_id ON blobs_keys USING btree (blob_id, key_id);


--
-- Name: index_blobs_on_project_id_and_sha_and_path_sha; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blobs_on_project_id_and_sha_and_path_sha ON blobs USING btree (project_id, sha, path_sha);


--
-- Name: index_commits_keys_on_commit_id_and_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commits_keys_on_commit_id_and_key_id ON commits_keys USING btree (commit_id, key_id);


--
-- Name: index_commits_keys_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commits_keys_on_created_at ON commits_keys USING btree (created_at);


--
-- Name: index_commits_on_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commits_on_fingerprint ON commits USING btree (fingerprint);


--
-- Name: index_commits_on_project_id_and_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_commits_on_project_id_and_revision ON commits USING btree (project_id, revision);


--
-- Name: index_in_section_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_in_section_unique ON keys USING btree (section_id, index_in_section) WHERE ((section_id IS NOT NULL) AND (index_in_section IS NOT NULL));


--
-- Name: index_keys_on_is_block_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keys_on_is_block_tag ON keys USING btree (is_block_tag);


--
-- Name: index_keys_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keys_on_project_id ON keys USING btree (project_id);


--
-- Name: index_keys_on_ready; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keys_on_ready ON keys USING btree (ready);


--
-- Name: index_keys_on_source_copy_sha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keys_on_source_copy_sha ON keys USING btree (source_copy_sha);


--
-- Name: index_locale_associations_on_source_and_target_rfc5646_locales; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_locale_associations_on_source_and_target_rfc5646_locales ON locale_associations USING btree (source_rfc5646_locale, target_rfc5646_locale);


--
-- Name: index_projects_on_api_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_api_token ON projects USING btree (api_token);


--
-- Name: index_sections_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_article_id ON sections USING btree (article_id);


--
-- Name: index_sections_on_article_id_and_name_sha; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sections_on_article_id_and_name_sha ON sections USING btree (article_id, name_sha);


--
-- Name: index_sections_on_name_sha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_name_sha ON sections USING btree (name_sha);


--
-- Name: index_translation_changes_on_translation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translation_changes_on_translation_id ON translation_changes USING btree (translation_id);


--
-- Name: index_translations_on_rfc5646_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_translations_on_rfc5646_locale ON translations USING btree (rfc5646_locale);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON users USING btree (confirmation_token);


--
-- Name: issues_translation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_translation ON issues USING btree (translation_id);


--
-- Name: issues_translation_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_translation_status ON issues USING btree (translation_id, status);


--
-- Name: issues_translation_status_priority_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_translation_status_priority_created_at ON issues USING btree (translation_id, status, priority, created_at);


--
-- Name: issues_updater; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_updater ON issues USING btree (updater_id);


--
-- Name: issues_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX issues_user ON issues USING btree (user_id);


--
-- Name: keys_in_section_unique_new; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX keys_in_section_unique_new ON keys USING btree (section_id, key_sha) WHERE (section_id IS NOT NULL);


--
-- Name: keys_unique_new; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX keys_unique_new ON keys USING btree (project_id, key_sha, source_copy_sha) WHERE (section_id IS NULL);


--
-- Name: projects_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX projects_name ON projects USING btree (lower((name)::text));


--
-- Name: slugs_for_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX slugs_for_record ON slugs USING btree (sluggable_type, sluggable_id, active);


--
-- Name: slugs_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX slugs_unique ON slugs USING btree (sluggable_type, lower((scope)::text), lower((slug)::text));


--
-- Name: translations_by_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX translations_by_key ON translations USING btree (key_id, rfc5646_locale);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email ON users USING btree (email);


--
-- Name: users_reset_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_reset_token ON users USING btree (reset_password_token);


--
-- Name: users_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_unlock_token ON users USING btree (unlock_token);


--
-- Name: articles articles_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY articles
    ADD CONSTRAINT articles_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: blobs_commits blobs_commits_blob_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_commits
    ADD CONSTRAINT blobs_commits_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES blobs(id) ON DELETE CASCADE;


--
-- Name: blobs_commits blobs_commits_commit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_commits
    ADD CONSTRAINT blobs_commits_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id) ON DELETE CASCADE;


--
-- Name: blobs_keys blobs_keys_blob_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_keys
    ADD CONSTRAINT blobs_keys_blob_id_fkey FOREIGN KEY (blob_id) REFERENCES blobs(id) ON DELETE CASCADE;


--
-- Name: blobs_keys blobs_keys_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs_keys
    ADD CONSTRAINT blobs_keys_key_id_fkey FOREIGN KEY (key_id) REFERENCES keys(id) ON DELETE CASCADE;


--
-- Name: blobs blobs_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blobs
    ADD CONSTRAINT blobs_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: comments comments_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE;


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: commits_keys commits_keys_commit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits_keys
    ADD CONSTRAINT commits_keys_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id) ON DELETE CASCADE;


--
-- Name: commits_keys commits_keys_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits_keys
    ADD CONSTRAINT commits_keys_key_id_fkey FOREIGN KEY (key_id) REFERENCES keys(id) ON DELETE CASCADE;


--
-- Name: commits commits_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits
    ADD CONSTRAINT commits_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: commits commits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commits
    ADD CONSTRAINT commits_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: issues issues_translation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY issues
    ADD CONSTRAINT issues_translation_id_fkey FOREIGN KEY (translation_id) REFERENCES translations(id) ON DELETE CASCADE;


--
-- Name: issues issues_updater_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY issues
    ADD CONSTRAINT issues_updater_id_fkey FOREIGN KEY (updater_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: issues issues_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY issues
    ADD CONSTRAINT issues_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: keys keys_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY keys
    ADD CONSTRAINT keys_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;


--
-- Name: keys keys_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY keys
    ADD CONSTRAINT keys_section_id_fkey FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE;


--
-- Name: locale_glossary_entries locale_glossary_entries_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: locale_glossary_entries locale_glossary_entries_source_glossary_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_source_glossary_entry_id_fkey FOREIGN KEY (source_glossary_entry_id) REFERENCES source_glossary_entries(id) ON DELETE CASCADE;


--
-- Name: locale_glossary_entries locale_glossary_entries_translator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locale_glossary_entries
    ADD CONSTRAINT locale_glossary_entries_translator_id_fkey FOREIGN KEY (translator_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: screenshots screenshots_commit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY screenshots
    ADD CONSTRAINT screenshots_commit_id_fkey FOREIGN KEY (commit_id) REFERENCES commits(id) ON DELETE CASCADE;


--
-- Name: sections sections_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sections
    ADD CONSTRAINT sections_article_id_fkey FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE;


--
-- Name: translation_changes translation_changes_translation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes
    ADD CONSTRAINT translation_changes_translation_id_fkey FOREIGN KEY (translation_id) REFERENCES translations(id) ON DELETE CASCADE;


--
-- Name: translation_changes translation_changes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translation_changes
    ADD CONSTRAINT translation_changes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: translations translations_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_key_id_fkey FOREIGN KEY (key_id) REFERENCES keys(id) ON DELETE CASCADE;


--
-- Name: translations translations_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: translations translations_translator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY translations
    ADD CONSTRAINT translations_translator_id_fkey FOREIGN KEY (translator_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

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

INSERT INTO schema_migrations (version) VALUES ('20140219040119');

INSERT INTO schema_migrations (version) VALUES ('20140228025058');

INSERT INTO schema_migrations (version) VALUES ('20140306064700');

INSERT INTO schema_migrations (version) VALUES ('20140311011156');

INSERT INTO schema_migrations (version) VALUES ('20140320053508');

INSERT INTO schema_migrations (version) VALUES ('20140518040822');

INSERT INTO schema_migrations (version) VALUES ('20140520233119');

INSERT INTO schema_migrations (version) VALUES ('20140521001017');

INSERT INTO schema_migrations (version) VALUES ('20140521010749');

INSERT INTO schema_migrations (version) VALUES ('20140521213501');

INSERT INTO schema_migrations (version) VALUES ('20140522002732');

INSERT INTO schema_migrations (version) VALUES ('20140523201654');

INSERT INTO schema_migrations (version) VALUES ('20140523201726');

INSERT INTO schema_migrations (version) VALUES ('20140531020536');

INSERT INTO schema_migrations (version) VALUES ('20140606111509');

INSERT INTO schema_migrations (version) VALUES ('20140613215228');

INSERT INTO schema_migrations (version) VALUES ('20140616232942');

INSERT INTO schema_migrations (version) VALUES ('20140714173058');

INSERT INTO schema_migrations (version) VALUES ('20140717192729');

INSERT INTO schema_migrations (version) VALUES ('20140721233942');

INSERT INTO schema_migrations (version) VALUES ('20140919214058');

INSERT INTO schema_migrations (version) VALUES ('20140925191736');

INSERT INTO schema_migrations (version) VALUES ('20140927210829');

INSERT INTO schema_migrations (version) VALUES ('20140930013949');

INSERT INTO schema_migrations (version) VALUES ('20141002074759');

INSERT INTO schema_migrations (version) VALUES ('20141022174649');

INSERT INTO schema_migrations (version) VALUES ('20141022191209');

INSERT INTO schema_migrations (version) VALUES ('20141022223754');

INSERT INTO schema_migrations (version) VALUES ('20141103204013');

INSERT INTO schema_migrations (version) VALUES ('20141104215833');

INSERT INTO schema_migrations (version) VALUES ('20141105193238');

INSERT INTO schema_migrations (version) VALUES ('20141113025632');

INSERT INTO schema_migrations (version) VALUES ('20141114011624');

INSERT INTO schema_migrations (version) VALUES ('20141114073933');

INSERT INTO schema_migrations (version) VALUES ('20141119005842');

INSERT INTO schema_migrations (version) VALUES ('20141119043427');

INSERT INTO schema_migrations (version) VALUES ('20141119215724');

INSERT INTO schema_migrations (version) VALUES ('20141119230218');

INSERT INTO schema_migrations (version) VALUES ('20141119235158');

INSERT INTO schema_migrations (version) VALUES ('20141120005608');

INSERT INTO schema_migrations (version) VALUES ('20141120006009');

INSERT INTO schema_migrations (version) VALUES ('20141120007440');

INSERT INTO schema_migrations (version) VALUES ('20141120011722');

INSERT INTO schema_migrations (version) VALUES ('20141121202324');

INSERT INTO schema_migrations (version) VALUES ('20141203212948');

INSERT INTO schema_migrations (version) VALUES ('20141205235631');

INSERT INTO schema_migrations (version) VALUES ('20141212011818');

INSERT INTO schema_migrations (version) VALUES ('20141212012945');

INSERT INTO schema_migrations (version) VALUES ('20141212232303');

INSERT INTO schema_migrations (version) VALUES ('20141217214242');

INSERT INTO schema_migrations (version) VALUES ('20141218002351');

INSERT INTO schema_migrations (version) VALUES ('20141229041151');

INSERT INTO schema_migrations (version) VALUES ('20141230094906');

INSERT INTO schema_migrations (version) VALUES ('20150228020547');

INSERT INTO schema_migrations (version) VALUES ('20150825010811');

INSERT INTO schema_migrations (version) VALUES ('20150828004150');

INSERT INTO schema_migrations (version) VALUES ('20151110220302');

INSERT INTO schema_migrations (version) VALUES ('20151210163604');

INSERT INTO schema_migrations (version) VALUES ('20151210165453');

INSERT INTO schema_migrations (version) VALUES ('20151210165629');

INSERT INTO schema_migrations (version) VALUES ('20151210170111');

INSERT INTO schema_migrations (version) VALUES ('20160229212753');

INSERT INTO schema_migrations (version) VALUES ('20160302033924');

INSERT INTO schema_migrations (version) VALUES ('20160303001118');

INSERT INTO schema_migrations (version) VALUES ('20160303235403');

INSERT INTO schema_migrations (version) VALUES ('20160404235737');

INSERT INTO schema_migrations (version) VALUES ('20160516051607');

INSERT INTO schema_migrations (version) VALUES ('20170508202319');

INSERT INTO schema_migrations (version) VALUES ('20171024225818');

INSERT INTO schema_migrations (version) VALUES ('20171103183318');

INSERT INTO schema_migrations (version) VALUES ('20171206152825');

INSERT INTO schema_migrations (version) VALUES ('20180129223845');

