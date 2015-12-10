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

require 'file_mutex'

# A project that requires localization. Each Project has a *base locale* that
# it is originally localized to (typically US English), and multiple *required
# locales* that must be satisfied before a given Commit of the Project is
# approved for release.
#
# Branch-based workflows
# ----------------------
#
# Shuttle supports automated branch-based workflows through two attributes,
# `watched_branches` and `touchdown_branch`. Shuttle automatically imports
# commits from `watched_branches`. The first watched branch is "special"; when
# a commit is translated on this branch, the `touchdown_branch` is advanced to
# that commit.
#
# To learn how to use these features to integrate Shuttle into your deploy
# pipeline, see the DEVELOPER_GUIDE.md file.
#
# Associations
# ============
#
# |                |                                                      |
# |:---------------|:-----------------------------------------------------|
# | `commits`      | The {Commit Commits} under this Project.             |
# | `keys`         | The {Key Keys} found in this Project.                |
# | `translations` | The {Translation Translations} under this Project.   |
# | `blobs`        | The Git {Blob Blobs} imported into this Project.     |
# | `articles`     | The {Article Articles} imported into this Project.   |
#
# Properties
# ==========
#
# |                           |                                                                                                                                                             |
# |:--------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------|
# | `api_token`               | A unique token used to refer to and authenticate this Project in API requests.                                                                              |
# | `name`                    | The Project's name.                                                                                                                                         |
# | `repository_url`          | The URL of the Project's Git repository.                                                                                                                    |
# | `base_locale`             | The locale the Project is initially localized in.                                                                                                           |
# | `locale_requirements`     | An hash mapping locales this Project can be localized to, to whether those locales are required.                                                            |
# | `skip_imports`            | An array of classes under the {Importer} module that are _not_ used to search for Translations.                                                             |
# | `key_exclusions`          | An array of globs that describe keys that should be ignored.                                                                                                |
# | `key_inclusions`          | An array of globs that describe keys that should be included. Other keys are ignored.                                                                       |
# | `key_locale_exclusions`   | A hash mapping a locale's RFC 5646 code to an array of globs that describes keys that should be ignored in that locale.                                     |
# | `key_locale_inclusions`   | A hash mapping a locale's RFC 5646 code to an array of globs that describes keys that will not be ignored in that locale.                                   |
# | `only_paths`              | An array of paths. If at least one path is set, other paths will not be searched for strings to import.                                                     |
# | `skip_paths`              | An array of paths that will not be searched for strings to import.                                                                                          |
# | `only_importer_paths`     | A hash mapping an importer class name to an array of paths. If at least one path is set, paths not in this list will not be searched.                       |
# | `skip_importer_paths`     | A hash mapping an importer class name to an array of paths that importer will not search under.                                                             |
# | `default_manifest_format` | The default format in which the manifest file will be exported. Must be {Exporter::Base.multilingual? multilingual}.                                        |
# | `watched_branches`        | A list of branches to automatically import new Commits from.                                                                                                |
# | `touchdown_branch`        | If this is set, Shuttle will reset the head of this branch to the most recently translated commit if that commit is accessible by the first watched branch. |
# | `manifest_directory`      | If this is set, Shuttle will automatically push a new commit containing the translated manifest in the specified directory to the touchdown branch.         |

class Project < ActiveRecord::Base
  # The directory where repositories are mirrored.
  REPOS_DIRECTORY = Rails.root.join('tmp', 'repos')
  # The directory where working repositories are checked out.
  WORKING_REPOS_DIRECTORY = Rails.root.join('tmp', 'working_repos')

  # @return [true, false] If `true`, Git will attempt to clone the repository,
  #   and add an error to the `repository_url` attribute if it cannot.
  attr_accessor :validate_repo_connectivity

  has_many :commits, inverse_of: :project, dependent: :destroy
  has_many :keys, inverse_of: :project, dependent: :destroy
  has_many :blobs, inverse_of: :project, dependent: :delete_all
  has_many :translations, through: :keys
  has_many :articles, inverse_of: :project
  has_many :sections, through: :articles

  serialize :skip_imports,             Array
  serialize :key_exclusions,           Array
  serialize :key_inclusions,           Array
  serialize :key_locale_exclusions,    Hash
  serialize :key_locale_inclusions,    Hash
  serialize :skip_paths,               Array
  serialize :only_paths,               Array
  serialize :skip_importer_paths,      Hash
  serialize :only_importer_paths,      Hash
  serialize :watched_branches,         Array

  # Add import_batch and import_batch_status methods
  extend SidekiqBatchManager
  sidekiq_batch :translations_adder_and_remover_batch do |batch|
    batch.description = "Project Translations Adder And Remover #{id} (#{name})"
    batch.on :success, ProjectTranslationsAdderAndRemover::Finisher, project_id: id
  end

  extend SetNilIfBlank
  set_nil_if_blank :repository_url
  set_nil_if_blank :github_webhook_url
  set_nil_if_blank :stash_webhook_url
  set_nil_if_blank :manifest_directory
  set_nil_if_blank :default_manifest_format

  include Slugalicious
  slugged :name

  include CommonLocaleLogic

  validates :name,
            presence: true,
            length:   {maximum: 256}
  validates :api_token,
            presence:   true,
            uniqueness: true,
            length:     {is: 240},
            format:     {with: /[0-9a-f\-]+/},
            strict:     true

  validate :can_clone_repo, if: :validate_repo_connectivity

  before_validation :create_api_token, on: :create
  before_validation { |obj| obj.skip_imports.reject!(&:blank?) }
  after_commit :add_or_remove_pending_translations, on: :update

  scope :git, -> { where("projects.repository_url IS NOT NULL") }
  scope :not_git, -> { where("projects.repository_url IS NULL") }

  # Returns a `Git::Repository` proxy object that allows you to work with the
  # local checkout of this Project's repository. The repository will be checked
  # out if it hasn't been already.
  #
  # If project is not linked to a git repository, {NotLinkedToAGitRepositoryError} is raised. This may happen if
  # this project is only used for articles.
  #
  # Any Git errors that occur when attempting to clone the repository are
  # swallowed, and `nil` is returned.
  #
  # @overload repo
  #   @return [Git::Repository, nil] The proxy object for the repository.
  #
  # @overload repo(&block)
  #   If passed a block, this method will lock a mutex and yield the repository,
  #   giving you exclusive access to the repository. This is recommended when
  #   performing any repository-altering operations (e.g., fetches). The mutex
  #   is freed when the block completes.
  #   @yield A block that is given exclusive control of the repository.
  #   @yieldparam [Git::Repository] repo The proxy object for the repository.
  #
  # @raise [Project::NotLinkedToAGitRepositoryError] If repository_url is blank.

  def repo
    raise NotLinkedToAGitRepositoryError unless git?
    if File.exist?(repo_path)
      @repo ||= Git.bare(repo_path)
    else
      repo_mutex.synchronize do
        @repo ||= begin
          exists = File.exist?(repo_path) || clone_repo
          exists ? Git.bare(repo_path) : nil
        end
      end
    end

    if block_given?
      raise "Repo not ready" unless @repo
      result = repo_mutex.synchronize { yield @repo }
      return result
    else
      return @repo
    end
  rescue Git::GitExecuteError
    raise "Repo not ready: #{$ERROR_INFO.to_s}"
  end

  # Returns a `Git::Repository` working directory object that allows you to work with the
  # local checkout of this Project's repository. The repository will be checked
  # out if it hasn't been already.
  #
  # If project is not linked to a git repository, {NotLinkedToAGitRepositoryError} is raised. This may happen if
  # this project is only used for articles.
  #
  # Any Git errors that occur when attempting to clone the repository are
  # swallowed, and `nil` is returned.
  #
  # @overload working_repo
  #   @return [Git::Repository, nil] The working directory object.
  #
  # @overload working_repo(&block)
  #   If passed a block, this method will lock a mutex and yield the working repository,
  #   giving you exclusive access to the working repository. This is recommended when
  #   performing any repository-altering operations (e.g., fetches). The mutex
  #   is freed when the block completes.
  #   @yield A block that is given exclusive control of the working repository.
  #   @yieldparam [Git::Repository] repo The proxy object for the wokring repository.
  #
  # @raise [Project::NotLinkedToAGitRepositoryError] If repository_url is blank.

  def working_repo
    raise NotLinkedToAGitRepositoryError unless git?
    if File.exist?(working_repo_path)
      @working_repo ||= Git.open(working_repo_path)
    else
      FileUtils::mkdir_p WORKING_REPOS_DIRECTORY
      working_repo_mutex.synchronize do
        @working_repo ||= begin
          exists = File.exist?(working_repo_path) || clone_working_repo
          exists ? Git.open(working_repo_path) : nil
        end
      end
    end

    if block_given?
      raise "Repo not ready" unless @working_repo
      result = working_repo_mutex.synchronize { yield @working_repo }
      return result
    else
      return @working_repo
    end
  rescue Git::GitExecuteError
    raise "Repo not ready: #{$ERROR_INFO.to_s}"
  end

  # Tells us if this {Project} is meant to be linked to a repository (ie. repo-backed vs article-backed).
  # It checks `repository_url` field to determine that.
  # Doesn't check if `repository_url` is valid.
  #
  # @return [Boolean] true if there is a repository_url present, false otherwise

  def git?
    repository_url.present?
  end

  # Reverse of git?
  def not_git?
    !git?
  end

  # Attempts to find or create a Commit object corresponding to a SHA or other
  # ref resolvable to a SHA (like "HEAD"). If the SHA is not found, performs a
  # fetch and attempts to create a Commit. If _that_ fails, raises an exception.
  #
  # @param [String] sha A SHA or ref resolvable to a SHA.
  # @param [Hash] options Additional options.
  # @option options [true, false] skip_import If `true`, does not perform an
  #   import after creating the Commit, if one was created.
  # @option options [true, false] skip_create If `true`, does not create a new
  #   Commit object if one is not found.
  # @option options [Hash] other_fields Additional model fields to set. Must
  #   have already been filtered for accessible attributes.
  # @return [Commit] The Commit for that SHA.
  # @raise [Git::CommitNotFoundError] If an unknown SHA is given.

  def commit!(sha, options={})
    commit_object = find_or_fetch_git_object(sha)
    raise Git::CommitNotFoundError, sha unless commit_object

    if options[:skip_create]
      commits.for_revision(commit_object.sha).first!
    else
      commits.for_revision(commit_object.sha).
          find_or_create!(revision:     commit_object.sha,
                          message:      commit_object.message,
                          committed_at: commit_object.author.date,
                          skip_import:  options[:skip_import]) do |c|
        options[:other_fields].each do |field, value|
          c.send :"#{field}=", value
        end if options[:other_fields]
      end
    end
  end

  def find_or_fetch_git_object(sha)
    repo do |r|
      r.object(sha) || (r.fetch; r.object(sha))
    end
  end

  def latest_commit
    commits.order('committed_at DESC').first
  end

  # Generates a new API token for the Project. Does not save the Project.
  def create_api_token(); self.api_token = SecureRandom.urlsafe_base64(180); end

  # Returns the number of Translations pending translation.
  #
  # @param [Locale] locale The locale to filter Translations by (defaults to
  #   Project's base locale).
  # @return [Fixnum] The number of untranslated Translations.

  def pending_translations(locale=nil)
    locale ||= base_locale
    translations.where(rfc5646_locale: locale.rfc5646, translated: false).count
  end

  # Returns the number of Translations pending review.
  #
  # @param [Locale] locale The locale to filter Translations by (defaults to
  #   Project's base locale).
  # @return [Fixnum] The number of unreviewed Translations.

  def pending_reviews(locale=nil)
    locale ||= base_locale
    translations.where(rfc5646_locale: locale.rfc5646, translated: true, approved: nil).count
  end

  # Tests a key against the key inclusions/exclusions and locale-based
  # inclusions/exclusions.
  #
  # @param [String] key A key to test.
  # @param [Locale] locale A locale that a Translation could be in.
  # @return [true, false] Whether such a Translation should _not_ be created.
  # @see Commit#skip_key?

  def skip_key?(key, locale)
    return true if key_exclusions.any? { |exclusion| File.fnmatch(exclusion, key) }
    return true if key_inclusions.present? && key_inclusions.none? { |inclusion| File.fnmatch(inclusion, key) }
    return true if (key_locale_exclusions[locale.rfc5646] || []).any? { |exclusion| File.fnmatch(exclusion, key) }
    if key_locale_inclusions[locale.rfc5646].present?
      return true if key_locale_inclusions[locale.rfc5646].none? { |exclusion| File.fnmatch(exclusion, key) }
    end
    return false
  end

  # Tests a path against the path inclusions/exclusions and locale-based
  # inclusions/exclusions.
  #
  # @param [String] path A path, relative to the project root, to test.
  # @param [Class] importer The class of an importer.
  # @return [true, false] If `true`, the path should _not_ be searched for
  #   strings.

  def skip_path?(path, importer)
    path = path.sub(/^\//, '')
    return false if path.empty?

    return true if skip_paths.any? { |sp| path.start_with?(sp) }
    return true if only_paths.present? && only_paths.none? { |op| path.start_with?(op) }
    return true if (skip_importer_paths[importer.ident] || []).any? { |sp| path.start_with?(sp) }
    if only_importer_paths[importer.ident].present?
      return true if only_importer_paths[importer.ident].none? { |op| path.start_with?(op) }
    end

    return false
  end

  # Tests a path and its subpaths against the path inclusions/exclusions and
  # locale-based inclusions/exclusions. Returns `true` only if that path and all
  # possible subpaths can be skipped.
  #
  # @param [String] path A path, relative to the project root, to test.
  # @return [true, false] If `true`, the path and its subpaths should _not_ be
  #   searched for strings.

  def skip_tree?(path)
    path = path.sub(/^\//, '')

    if only_paths.present? || only_importer_paths.present?
      # we can't skip this path if any of the only_paths have this path as a
      # child or parent.
      # otherwise we can, since the only paths we care about are unrelated to
      # this path
      paths = only_paths + only_importer_paths.values.flatten.compact
      return paths.none? { |op| op.start_with?(path) || path.start_with?(op) }
    end

    return false if only_importer_paths.values.flatten.compact.any? { |op| op.start_with?(path) }
    # we can skip this path if at least one of the skip_paths are subpaths of
    # this path
    return skip_paths.any? { |sp| path.start_with?(sp) } ||
        skip_importer_paths.values.flatten.compact.any? { |sp| path.start_with?(sp) }
  end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :base_rfc5646_locale
    options[:except] << :targeted_rfc5646_locales

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :base_locale
    options[:methods] << :targeted_rfc5646_locales
    options[:methods] << :slug

    super options
  end

  private

  def repo_path
    return @_repo_path if instance_variable_defined?(:@_repo_path)
    @_repo_path = repo_directory.present? ? REPOS_DIRECTORY.join(repo_directory) : nil
  end

  def repo_directory
    return @_repo_dir if instance_variable_defined?(:@_repo_dir)
    @_repo_dir = git? ? (Digest::SHA1.hexdigest(repository_url) + '.git') : nil
  end

  def working_repo_path
    return @_working_repo_path if instance_variable_defined?(:@_working_repo_path)
    @_working_repo_path = working_repo_directory.present? ? WORKING_REPOS_DIRECTORY.join(working_repo_directory) : nil
  end

  def working_repo_directory
    return @_working_repo_dir if instance_variable_defined?(:@_working_repo_dir)
    @_working_repo_dir = git? ? Digest::SHA1.hexdigest(repository_url) : nil
  end

  def clone_repo
    raise NotLinkedToAGitRepositoryError unless git?
    Git.clone repository_url, repo_directory, path: REPOS_DIRECTORY.to_s, mirror: true
  end

  def clone_working_repo
    raise NotLinkedToAGitRepositoryError unless git?
    Git.clone repository_url, working_repo_directory, path: WORKING_REPOS_DIRECTORY.to_s
  end

  def can_clone_repo
    errors.add(:repository_url, :unreachable) unless git? && repo
  end

  def repo_mutex
    @repo_mutex = FileMutex.new(repo_path.to_s + '.lock')
  end

  def working_repo_mutex
    @working_repo_mutex = FileMutex.new(working_repo_path.to_s + '.lock')
  end

  # If locale related fields changed, runs ProjectTranslationsAdderAndRemover for git-based projects
  def add_or_remove_pending_translations
    if git? && %w{targeted_rfc5646_locales key_exclusions key_inclusions key_locale_exclusions key_locale_inclusions}.any?{|field| previous_changes.include?(field)}
      translations_adder_and_remover_batch.jobs do
        ProjectTranslationsAdderAndRemover.perform_once(id)
      end
    end
  end

  # ERRORS
  # This error will be raised when there are problems related to a repository.
  # This error class will most likely not be raised directly, but will be subclassed by more specific error classes.
  class InvalidRepositoryError < StandardError; end;

  # This error will be raised if project doesn't have a repository_url, and we attempt to
  # initialize a `Git::Repository` object (project.repo) or make a remote call to a git repo.
  class NotLinkedToAGitRepositoryError < InvalidRepositoryError
    def initialize
      super("repository_url is empty")
    end
  end
end
