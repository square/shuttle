# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171024225818) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "articles", force: true do |t|
    t.integer  "project_id",                                           null: false
    t.text     "name",                                                 null: false
    t.text     "sections_hash",                                        null: false
    t.string   "base_rfc5646_locale",                                  null: false
    t.text     "targeted_rfc5646_locales",                             null: false
    t.text     "description"
    t.string   "email"
    t.string   "import_batch_id"
    t.boolean  "ready",                                default: false, null: false
    t.datetime "first_import_requested_at"
    t.datetime "last_import_requested_at"
    t.datetime "first_import_started_at"
    t.datetime "last_import_started_at"
    t.datetime "first_import_finished_at"
    t.datetime "last_import_finished_at"
    t.datetime "first_completed_at"
    t.datetime "last_completed_at"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.date     "due_date"
    t.integer  "priority"
    t.integer  "creator_id"
    t.integer  "updater_id"
    t.boolean  "created_via_api",                      default: true,  null: false
    t.string   "name_sha",                  limit: 64,                 null: false
    t.boolean  "hidden",                               default: false, null: false
  end

  add_index "articles", ["name_sha"], name: "index_articles_on_name_sha", using: :btree
  add_index "articles", ["project_id", "name_sha"], name: "index_articles_on_project_id_and_name_sha", unique: true, using: :btree
  add_index "articles", ["project_id"], name: "index_articles_on_project_id", using: :btree
  add_index "articles", ["ready"], name: "index_articles_on_ready", using: :btree

  create_table "blobs", force: true do |t|
    t.integer  "project_id",                            null: false
    t.boolean  "parsed",                default: false, null: false
    t.boolean  "errored",               default: false, null: false
    t.text     "path",                                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "sha",        limit: 40,                 null: false
    t.string   "path_sha",   limit: 64,                 null: false
  end

  add_index "blobs", ["project_id", "sha", "path_sha"], name: "index_blobs_on_project_id_and_sha_and_path_sha", unique: true, using: :btree

  create_table "blobs_commits", force: true do |t|
    t.integer  "commit_id",  null: false
    t.integer  "blob_id",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "blobs_commits", ["blob_id", "commit_id"], name: "index_blobs_commits_on_blob_id_and_commit_id", unique: true, using: :btree

  create_table "blobs_keys", force: true do |t|
    t.integer  "key_id",     null: false
    t.integer  "blob_id",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "blobs_keys", ["blob_id", "key_id"], name: "index_blobs_keys_on_blob_id_and_key_id", unique: true, using: :btree

  create_table "comments", force: true do |t|
    t.integer  "user_id"
    t.integer  "issue_id",   null: false
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["issue_id"], name: "comments_issue", using: :btree
  add_index "comments", ["user_id"], name: "comments_user", using: :btree

  create_table "commits", force: true do |t|
    t.integer  "project_id",                                   null: false
    t.string   "message",          limit: 256,                 null: false
    t.datetime "committed_at",                                 null: false
    t.boolean  "ready",                        default: false, null: false
    t.boolean  "loading",                      default: false, null: false
    t.datetime "created_at"
    t.date     "due_date"
    t.integer  "priority"
    t.integer  "user_id"
    t.datetime "completed_at"
    t.boolean  "exported",                     default: false, null: false
    t.datetime "loaded_at"
    t.text     "description"
    t.string   "author"
    t.string   "author_email"
    t.text     "pull_request_url"
    t.string   "import_batch_id"
    t.text     "import_errors"
    t.string   "revision",         limit: 40,                  null: false
  end

  add_index "commits", ["priority", "due_date"], name: "commits_priority", using: :btree
  add_index "commits", ["project_id", "committed_at"], name: "commits_date", using: :btree
  add_index "commits", ["project_id", "ready", "committed_at"], name: "commits_ready_date", using: :btree
  add_index "commits", ["project_id", "revision"], name: "index_commits_on_project_id_and_revision", unique: true, using: :btree

  create_table "commits_keys", id: false, force: true do |t|
    t.integer  "commit_id",  null: false
    t.integer  "key_id",     null: false
    t.datetime "created_at"
  end

  add_index "commits_keys", ["commit_id", "key_id"], name: "index_commits_keys_on_commit_id_and_key_id", unique: true, using: :btree
  add_index "commits_keys", ["created_at"], name: "index_commits_keys_on_created_at", using: :btree
  add_index "commits_keys", ["key_id"], name: "commits_keys_key_id", using: :btree

  create_table "daily_metrics", force: true do |t|
    t.date     "date",                              null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "num_commits_loaded"
    t.text     "num_commits_loaded_per_project"
    t.float    "avg_load_time"
    t.text     "avg_load_time_per_project"
    t.integer  "num_commits_completed"
    t.text     "num_commits_completed_per_project"
    t.integer  "num_words_created"
    t.text     "num_words_created_per_language"
    t.integer  "num_words_completed"
    t.text     "num_words_completed_per_language"
  end

  add_index "daily_metrics", ["date"], name: "daily_metrics_date", unique: true, using: :btree

  create_table "issues", force: true do |t|
    t.integer  "user_id"
    t.integer  "updater_id"
    t.integer  "translation_id",    null: false
    t.string   "summary"
    t.text     "description"
    t.integer  "priority"
    t.integer  "kind"
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "subscribed_emails"
  end

  add_index "issues", ["translation_id", "status", "priority", "created_at"], name: "issues_translation_status_priority_created_at", using: :btree
  add_index "issues", ["translation_id", "status"], name: "issues_translation_status", using: :btree
  add_index "issues", ["translation_id"], name: "issues_translation", using: :btree
  add_index "issues", ["updater_id"], name: "issues_updater", using: :btree
  add_index "issues", ["user_id"], name: "issues_user", using: :btree

  create_table "keys", force: true do |t|
    t.integer "project_id",                                  null: false
    t.boolean "ready",                       default: true,  null: false
    t.text    "key",                                         null: false
    t.text    "original_key",                                null: false
    t.text    "source_copy"
    t.text    "context"
    t.string  "importer"
    t.text    "source"
    t.text    "fencers"
    t.text    "other_data"
    t.integer "section_id"
    t.integer "index_in_section"
    t.boolean "is_block_tag",                default: false, null: false
    t.string  "key_sha",          limit: 64,                 null: false
    t.string  "source_copy_sha",  limit: 64,                 null: false
    t.boolean "hidden_in_search",            default: false
  end

  add_index "keys", ["is_block_tag"], name: "index_keys_on_is_block_tag", using: :btree
  add_index "keys", ["project_id", "key_sha", "source_copy_sha"], name: "keys_unique_new", unique: true, where: "(section_id IS NULL)", using: :btree
  add_index "keys", ["project_id"], name: "index_keys_on_project_id", using: :btree
  add_index "keys", ["ready"], name: "index_keys_on_ready", using: :btree
  add_index "keys", ["section_id", "index_in_section"], name: "index_in_section_unique", unique: true, where: "((section_id IS NOT NULL) AND (index_in_section IS NOT NULL))", using: :btree
  add_index "keys", ["section_id", "key_sha"], name: "keys_in_section_unique_new", unique: true, where: "(section_id IS NOT NULL)", using: :btree
  add_index "keys", ["source_copy_sha"], name: "index_keys_on_source_copy_sha", using: :btree

  create_table "locale_associations", force: true do |t|
    t.string   "source_rfc5646_locale",                 null: false
    t.string   "target_rfc5646_locale",                 null: false
    t.boolean  "checked",               default: false, null: false
    t.boolean  "uncheck_disabled",      default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "locale_associations", ["source_rfc5646_locale", "target_rfc5646_locale"], name: "index_locale_associations_on_source_and_target_rfc5646_locales", unique: true, using: :btree

  create_table "locale_glossary_entries", force: true do |t|
    t.integer  "translator_id"
    t.integer  "reviewer_id"
    t.integer  "source_glossary_entry_id"
    t.string   "rfc5646_locale",           limit: 15,                 null: false
    t.boolean  "translated",                          default: false, null: false
    t.boolean  "approved"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "copy"
    t.text     "notes"
  end

  create_table "projects", force: true do |t|
    t.string   "name",                                         limit: 256,                 null: false
    t.string   "repository_url",                               limit: 256
    t.datetime "created_at"
    t.string   "translations_adder_and_remover_batch_id"
    t.boolean  "disable_locale_association_checkbox_settings",             default: false, null: false
    t.string   "base_rfc5646_locale",                                      default: "en",  null: false
    t.text     "targeted_rfc5646_locales"
    t.text     "skip_imports"
    t.text     "key_exclusions"
    t.text     "key_inclusions"
    t.text     "key_locale_exclusions"
    t.text     "key_locale_inclusions"
    t.text     "skip_paths"
    t.text     "only_paths"
    t.text     "skip_importer_paths"
    t.text     "only_importer_paths"
    t.string   "default_manifest_format"
    t.text     "watched_branches"
    t.string   "touchdown_branch"
    t.text     "manifest_directory"
    t.string   "manifest_filename"
    t.text     "github_webhook_url"
    t.text     "stash_webhook_url"
    t.string   "api_token",                                    limit: 240,                 null: false
  end

  add_index "projects", ["api_token"], name: "index_projects_on_api_token", unique: true, using: :btree

  create_table "screenshots", force: true do |t|
    t.integer  "commit_id",          null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
  end

  create_table "sections", force: true do |t|
    t.integer  "article_id",                                null: false
    t.text     "name",                                      null: false
    t.text     "source_copy",                               null: false
    t.boolean  "active",                     default: true, null: false
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.string   "name_sha",        limit: 64,                null: false
    t.string   "source_copy_sha", limit: 64,                null: false
  end

  add_index "sections", ["article_id", "name_sha"], name: "index_sections_on_article_id_and_name_sha", unique: true, using: :btree
  add_index "sections", ["article_id"], name: "index_sections_on_article_id", using: :btree
  add_index "sections", ["name_sha"], name: "index_sections_on_name_sha", using: :btree

  create_table "slugs", force: true do |t|
    t.integer  "sluggable_id",                              null: false
    t.boolean  "active",                     default: true, null: false
    t.string   "slug",           limit: 126,                null: false
    t.string   "scope",          limit: 126
    t.datetime "created_at",                                null: false
    t.string   "sluggable_type", limit: 126,                null: false
  end

  add_index "slugs", ["sluggable_type", "sluggable_id", "active"], name: "slugs_for_record", using: :btree
  add_index "slugs", ["sluggable_type"], name: "slugs_unique", unique: true, using: :btree

  create_table "source_glossary_entries", force: true do |t|
    t.string   "source_rfc5646_locale", limit: 15, default: "en", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "source_copy",                                     null: false
    t.text     "context"
    t.text     "notes"
    t.date     "due_date"
    t.string   "source_copy_sha",       limit: 64,                null: false
  end

  create_table "translation_changes", force: true do |t|
    t.integer  "translation_id", null: false
    t.datetime "created_at"
    t.integer  "user_id"
    t.text     "diff"
  end

  add_index "translation_changes", ["translation_id"], name: "index_translation_changes_on_translation_id", using: :btree

  create_table "translations", force: true do |t|
    t.integer  "key_id",                                           null: false
    t.integer  "translator_id"
    t.integer  "reviewer_id"
    t.string   "source_rfc5646_locale", limit: 15,                 null: false
    t.string   "rfc5646_locale",        limit: 15,                 null: false
    t.boolean  "translated",                       default: false, null: false
    t.boolean  "approved"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "words_count",                      default: 0,     null: false
    t.text     "source_copy"
    t.text     "copy"
    t.text     "notes"
  end

  add_index "translations", ["key_id", "rfc5646_locale"], name: "translations_by_key", unique: true, using: :btree
  add_index "translations", ["rfc5646_locale"], name: "index_translations_on_rfc5646_locale", using: :btree

  create_table "users", force: true do |t|
    t.string   "email",                                           null: false
    t.string   "reset_password_token"
    t.integer  "sign_in_count",                       default: 0, null: false
    t.integer  "failed_attempts",                     default: 0, null: false
    t.string   "unlock_token"
    t.string   "role",                     limit: 50
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "confirmation_token"
    t.string   "first_name",                                      null: false
    t.string   "last_name",                                       null: false
    t.string   "encrypted_password",                              null: false
    t.datetime "remember_created_at"
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.datetime "locked_at"
    t.datetime "reset_password_sent_at"
    t.text     "approved_rfc5646_locales"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "users_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "users_reset_token", unique: true, using: :btree
  add_index "users", ["unlock_token"], name: "users_unlock_token", unique: true, using: :btree

end
