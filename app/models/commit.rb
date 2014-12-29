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

require 'fileutils'

# A state in a {Project}'s source history. A commit, in the context of this
# program, is a point in the history of a Project that is either approved or not
# approved for release, from a localization standpoint.
#
# Each new Commit, when created, is scanned for importable blobs. These blobs
# are scraped for {Key Keys} and {Translation Translations}, which are added to
# the corpus, and new {Blob} records are created. If the commit shares blobs
# with an already-imported commit, the blob is skipped.
#
# Existing keys are updated with new base translations, if the copy has changed,
# and translations are marked as pending review. Translations are created for
# any new Keys and marked as pending translation and review.
#
# Once all Translations of a Commit are translated and reviewed,
# that Commit is considered localized for that locale. Once all required
# locales have been reviewed, the Commit is ready for release. `after_save`
# hooks on {Translation} automatically manage the `ready` field, and the
# various workers method manage the `loading` field.
#
# Keys are child to a Project, not a Commit. A Commit has a many-to-many
# association that tracks which keys can be found under that commit.
#
# Associations
# ============
#
# |                |                                                        |
# |:---------------|:-------------------------------------------------------|
# | `project`      | The {Project} this is a Commit under.                  |
# | `user`         | The {User} that submitted this Commit for translation. |
# | `keys`         | All the {Key Keys} found in this Commit.               |
# | `translations` | The {Translation Translations} found in this Commit.   |
# | `blobs`        | The {Blob Blobs} found in this Commit.                 |
#
# Properties
# ==========
#
# |                    |                                                                                                          |
# |:-------------------|:---------------------------------------------------------------------------------------------------------|
# | `committed_at`     | The time this commit was made.                                                                           |
# | `message`          | The commit message.                                                                                      |
# | `ready`            | If `true`, all Keys under this Commit are marked as ready.                                               |
# | `exported`         | If `true`, monitor has already exported this commit and no longer needs it.                              |
# | `revision`         | The SHA1 for this commit.                                                                                |
# | `loading`          | If `true`, there is at least one {BlobImporter} processing this Commit.                                  |
# | `priority`         | An administrator-set priority arbitrarily defined as a number between 0 (highest) and 3 (lowest).        |
# | `due_date`         | A date displayed to translators and reviewers informing them of when the Commit must be fully localized. |
# | `completed_at`     | The date this Commit completed translation.                                                              |
# | `description`      | A user-submitted description of why we are localizing this commit.                                       |
# | `pull_request_url` | A user-submitted URL to the pull request that is being localized.                                        |
# | `import_batch_id`  | The ID of the Sidekiq batch of import jobs.                                                              |
# | `import_errors`    | Array of import errors that happened during the import process.                                          |
# | `author`           | The name of the commit author.                                                                           |
# | `author_email`     | The email address of the commit author.                                                                  |

class Commit < ActiveRecord::Base
  include CommitTraverser
  include ImportErrors

  # @return [true, false] If `true`, does not perform an import after creating
  #   the Commit. Use this to avoid the overhead of making an HTTP request and
  #   spawning a worker for situations where Commits are being added in bulk.
  attr_accessor :skip_import

  belongs_to :project, inverse_of: :commits
  belongs_to :user, inverse_of: :commits
  has_many :commits_keys, inverse_of: :commit, dependent: :delete_all
  has_many :screenshots, inverse_of: :commit, dependent: :destroy
  has_many :keys, through: :commits_keys
  has_many :translations, through: :keys
  has_many :blobs_commits, inverse_of: :commit, dependent: :delete_all
  has_many :blobs, through: :blobs_commits
  has_many :issues, through: :translations

  include ArticleOrCommitStats
  alias_method :active_translations, :translations # called in ArticleOrCommitStats
  alias_method :active_keys, :keys # called in ArticleOrCommitStats
  alias_method :active_issues, :issues # called in ArticleOrCommitIssuesPresenter

  include Tire::Model::Search
  include Tire::Model::Callbacks
  mapping do
    indexes :project_id, type: 'integer'
    indexes :user_id, type: 'integer'
    indexes :priority, type: 'integer'
    indexes :due_date, type: 'date'
    indexes :created_at, type: 'date'
    indexes :revision, as: 'revision', index: :not_analyzed
    indexes :ready, type: 'boolean'
    indexes :exported, type: 'boolean'
    indexes :key_ids, as: 'commits_keys.pluck(:key_id)'
  end

  validates :project,
            presence: true
  validates :revision_raw,
            presence:   true,
            uniqueness: {scope: :project_id, on: :create}
  validates :message,
            presence: true,
            length:   {maximum: 256}
  validates :committed_at,
            presence:   true,
            timeliness: {type: :time}
  validates :priority,
            numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3},
            allow_nil:    true
  validates :due_date,
            timeliness: {type: :date},
            allow_nil:  true
  validates :completed_at,
            timeliness: {type: :date},
            allow_nil:  true

  attr_readonly :project_id, :revision_raw, :message, :committed_at

  extend GitObjectField
  git_object_field :revision,
                   git_type:        :commit,
                   repo:            ->(c) { c.project.try!(:repo) },
                   repo_must_exist: true,
                   scope:           :for_revision

  # Scopes
  scope :ready, -> { where(ready: true) }
  scope :not_ready, -> { where(ready: false) }

  # Add import_batch and import_batch_status methods
  extend SidekiqBatchManager
  sidekiq_batch :import_batch do |batch|
    batch.description = "Import Commit #{id} (#{revision})"
    batch.on :success, CommitImporter::Finisher, commit_id: id
  end

  extend SetNilIfBlank
  set_nil_if_blank :description, :due_date, :pull_request_url

  before_validation :load_message, on: :create
  before_validation(on: :create) do |obj|
    obj.message = obj.message.truncate(256) if obj.message
  end

  before_save :set_loaded_at
  before_create :set_author
  after_commit :initial_import, on: :create

  attr_readonly :revision, :message
  delegate :required_locales, :required_rfc5646_locales, :targeted_rfc5646_locales, :locale_requirements, to: :project

  # Counts the total commits.
  #
  # @return [Fixnum] The number of commits

  def self.total_commits
    Commit.all.count
  end

  # Counts the number of incomplete commits.  
  #
  # @return [Fixnum] The number of incomplete commits

  def self.total_commits_incomplete
    Commit.where('ready=false').count
  end

  # @private
  def to_param() revision end

  # Displays the revision prefix (i.e. first 6 characters of SHA)
  # of a commit
  def revision_prefix
    revision[0, 6]
  end

  # Calculates the value of the `ready` field and saves the record.
  # If this is the first time a commit has been marked as ready, sets
  # completed_at to be the current time.

  def recalculate_ready!
    self.ready = successfully_loaded? && keys_are_ready? && !errored_during_import?
    self.completed_at = Time.current if self.ready && self.completed_at.nil?
    save!
  end

  # Returns `true` if all Translations applying to this commit have been
  # translated to this locale and reviewed.
  #
  # @param [Locale] locale The locale.
  # @return [true, false] Whether localization is complete for that locale.

  def localized?(locale)
    translations.where(rfc5646_locale: locale.rfc5646).where('approved IS NOT TRUE').count == 0
  end

  # Recursively locates blobs in this commit, creates Blobs for each of them if
  # necessary, and calls {Blob#import_strings} on them.
  #
  # @param [Hash] options Import options.
  # @option options [Locale] locale The locale to assume the base copy is
  #   written in (by default it's the Project's base locale).
  # @option options [true, false] inline (false) If `true`, does not spawn
  #   Sidekiq workers to perform the import in parallel.
  # @option options [true, false] force (false) If `true`, blobs will be
  #   re-scanned for keys even if they have already been scanned.
  # @raise [Git::CommitNotFoundError] If the commit could not be found in
  #   the Git repository.

  def import_strings(options={})
    update_attribute :loading, true
    commit! # Make sure commit exists
    clear_import_errors! # clear out any previous import errors

    import_batch.jobs do
      blobs = project.blobs.includes(:project) # preload blobs for performance

      # clear out existing keys so that we can import all new keys
      commits_keys.delete_all unless options[:locale]
      # perform the recursive import
      traverse(commit!) do |path, blob|
        import_blob path, blob, options.merge(blobs: blobs)
      end
    end
  end

  # Returns a commit object used to interact with Git.
  #
  # @return [Git::Object::Commit, nil] The commit object.

  def commit
    project.repo.object(revision)
  end

  # Same as {#commit}, but fetches the upstream repository changes if the commit
  # is unrecognized.
  #
  # @return [Git::Object::Commit] The commit object.
  # @raise [Git::CommitNotFoundError] If the commit could not be found in
  #   the Git repository.

  def commit!
    unless commit_object = project.find_or_fetch_git_object(revision)
      raise Git::CommitNotFoundError, revision
    end
    commit_object
  end

  # @return [String, nil] The URL to this commit on GitHub, GitHub Enterprise or on Stash,
  #   or `nil` if the URL could not be determined.

  def git_url
    github_enterprise_domain = Shuttle::Configuration.app[:github_enterprise_domain]
    stash_domain = Shuttle::Configuration.app[:stash_domain]
    escaped_github_enterprise_domain = Regexp.escape(github_enterprise_domain)
    escaped_stash_domain = Regexp.escape(stash_domain)
    path_regex = "([^\/]+)\/(.+)\.git$"

    if project.repository_url =~ /^git@github\.com:#{path_regex}/ ||
        project.repository_url =~ /https:\/\/github\.com\/#{path_regex}/ # GitHub
      "https://github.com/#{$1}/#{$2}/commit/#{revision}"
    elsif project.repository_url =~ /^git@#{escaped_github_enterprise_domain}:#{path_regex}/ ||
        project.repository_url =~ /^https:\/\/#{escaped_github_enterprise_domain}\/#{path_regex}/ # Github Enterprise: git.mycompany.com
      "https://#{github_enterprise_domain}/#{$1}/#{$2}/commit/#{revision}"
    elsif project.repository_url =~ /^https:\/\/#{escaped_stash_domain}\/scm\/#{path_regex}/ # Stash: stash.mycompany.com
      "https://#{stash_domain}/projects/#{$1.upcase}/repos/#{$2}/commits/#{revision}"
    end
  end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :git_url << :revision

    options[:except] = Array.wrap(options[:except])
    options[:except] << :revision_raw

    super options
  end

  # Returns whether we should skip a key for this particular commit, given the
  # contents of the `.shuttle.yml` file for this commit.
  #
  # @param [String] key The key to potentially skip.
  # @return [true, false] Whether the key should not be associated with this
  # commit.
  # @see Project#skip_key?

  def skip_key?(key)
    key_exclusions = Rails.cache.fetch("commit:#{revision}:exclusions") do
      blob = commit!.gtree.blobs['.shuttle.yml']
      return unless blob
      settings = YAML.load(blob.contents)
      settings['key_exclusions']
    end

    if key_exclusions.kind_of?(Array)
      return true if key_exclusions.any? { |exclusion| File.fnmatch(exclusion, key) }
    end

    return false
  rescue Psych::SyntaxError
    return false
  end

  # @private
  def inspect(default_behavior=false)
    return super() if default_behavior
    state = if loading?
              'loading'
            else
              ready? ? 'ready' : 'not ready'
            end
    "#<#{self.class.to_s} #{id}: #{revision} (#{state})>"
  end

  # Returns `true` if this commit is currently not loading and
  # has successfully loaded at least once.
  #
  # @return [true, false] Whether the commit has successfully loaded.

  def successfully_loaded?
    loaded_at.present? && !loading?
  end

  # Returns `true` if all Keys associated with this commit are ready.
  #
  # @return [true, false] Whether all keys are ready for this commit.

  def keys_are_ready?
    !keys.where(ready: false).exists?
  end

  private

  def load_message
    self.message ||= commit!.message
    true
  end

  def set_loaded_at
    self.loaded_at ||= Time.current if self.loading_was && !self.loading
  end

  def set_author
    begin
      self.author = commit.author.name
      self.author_email = commit.author.email
    rescue
      # Don't set the author if commit doesn't exist
    end
  end

  def import_blob(path, blob, options={})
    return if project.skip_tree?(path)
    imps = Importer::Base.implementations.reject { |imp| project.skip_imports.include?(imp.ident) }

    blob_object = if options[:blobs]
                    begin
                      options[:blobs].detect { |b| b.sha == blob.sha } || begin
                        blob = project.blobs.with_sha(blob.sha).create!(sha: blob.sha)
                        options[:blobs] << blob
                        blob
                      end
                    rescue ActiveRecord::RecordNotUnique
                      project.blobs.with_sha(blob.sha).find_or_create!(sha: blob.sha)
                    end
                  else
                    project.blobs.with_sha(blob.sha).find_or_create!(sha: blob.sha)
                  end

    imps.each do |importer|
      importer = importer.new(blob_object, path, self)

      # we can't do a force import on a loading blob -- if we delete all the
      # blobs_keys while another sidekiq job is doing the import, when that job
      # finishes the blob will unset loading, even though the former job is still
      # adding keys to the blob. at this point a third import (with force=false)
      # might start, see the blob as not loading, and then do a fast import of
      # the cached keys (even though not all keys have been loaded by the second
      # import).
      if options[:force] && blob_object.parsed?
        blob_object.blobs_keys.delete_all
        blob_object.update_column :parsed, false
      end

      if importer.skip?(options[:locale])
        #Importer::SKIP_LOG.info "commit=#{revision} blob=#{blob.sha} path=#{blob_path} importer=#{importer.class.ident} #skip? returned true for #{options[:locale].inspect}"
        next
      end

      if options[:inline]
        BlobImporter.new.perform importer.class.ident, project.id, blob.sha, path, id, options[:locale].try!(:rfc5646)
      else
        BlobImporter.perform_once importer.class.ident, project.id, blob.sha, path, id, options[:locale].try!(:rfc5646)
      end
    end
  end

  #TODO there's a bug in Rails core that causes this to be run on update as well
  # as create. sigh.
  def initial_import
    return if @_start_transaction_state[:id] # fix bug in Rails core
    unless skip_import || loading?
      import_batch.jobs do
        CommitImporter.perform_once id
      end
    end
  end
end
