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
# Associations
# ============
#
# |                |                                                    |
# |:---------------|:---------------------------------------------------|
# | `commits`      | The {Commit Commits} under this Project.           |
# | `keys`         | The {Key Keys} found in this Project.              |
# | `translations` | The {Translation Translations} under this Project. |
# | `blobs`        | The Git {Blob Blobs} imported into this Project.   |
#
# Properties
# ==========
#
# |                  |                                                                              |
# |:-----------------|:-----------------------------------------------------------------------------|
# | `api_key`        | A unique key used to refer to and authenticate this Project in API requests. |
# | `name`           | The Project's name.                                                          |
# | `repository_url` | The URL of the Project's Git repository.                                     |
#
# Metadata
# ========
#
# |                          |                                                                                                                                                                                              |
# |:-------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
# | `base_locale`            | The locale the Project is initially localized in.                                                                                                                                            |
# | `locale_requirements`    | An hash mapping locales this Project can be localized to, to whether those locales are required.                                                                                             |
# | `skip_imports`           | An array of classes under the {Importer} module that are _not_ used to search for Translations.                                                                                              |
# | `key_exclusions`         | An array of globs that describe keys that should be ignored.                                                                                                                                 |
# | `key_inclusions`         | An array of globs that describe keys that should be included. Other keys are ignored.                                                                                                        |
# | `key_locale_exclusions`  | A hash mapping a locale's RFC 5646 code to an array of globs that describes keys that should be ignored in that locale.                                                                      |
# | `key_locale_inclusions`  | A hash mapping a locale's RFC 5646 code to an array of globs that describes keys that will not be ignored in that locale.                                                                    |
# | `only_paths`             | An array of paths. If at least one path is set, other paths will not be searched for strings to import.                                                                                      |
# | `skip_paths`             | An array of paths that will not be searched for strings to import.                                                                                                                           |
# | `only_importer_paths`    | A hash mapping an importer class name to an array of paths. If at least one path is set, paths not in this list will not be searched.                                                        |
# | `skip_importer_paths`    | A hash mapping an importer class name to an array of paths that importer will not search under.                                                                                              |
# | `cache_localization`     | If `true`, a precompiled localization will be generated and cached for each new Commit once it is ready.                                                                                     |
# | `cache_manifest_formats` | A precompiled manifest will be generated and cached for each exporter in this list (referenced by format parameter). Included exporters must be {Exporter::Base.multilingual? multilingual}. |
# | `watched_branches`       | A list of branches to automatically import new Commits from.                                                                                                                                 |

class Project < ActiveRecord::Base
  # The directory where repositories are checked out.
  REPOS_DIRECTORY = Rails.root.join('tmp', 'repos')

  # @return [true, false] If `true`, Git will attempt to clone the repository,
  #   and add an error to the `repository_url` attribute if it cannot.
  attr_accessor :validate_repo_connectivity

  has_many :commits, inverse_of: :project, dependent: :destroy
  has_many :keys, inverse_of: :project, dependent: :destroy
  has_many :blobs, inverse_of: :project, dependent: :delete_all
  has_many :translations, through: :keys

  include HasMetadataColumn
  has_metadata_column(
      base_rfc5646_locale:      {presence: true, default: 'en', format: {with: Locale::RFC5646_FORMAT}},
      targeted_rfc5646_locales: {presence: true, type: Hash, default: {'en' => true}},

      skip_imports:             {type: Array, default: []},

      key_exclusions:           {type: Array, default: [], allow_nil: false},
      key_inclusions:           {type: Array, default: [], allow_nil: false},
      key_locale_exclusions:    {type: Hash, default: {}, allow_nil: false},
      key_locale_inclusions:    {type: Hash, default: {}, allow_nil: false},

      only_paths:               {type: Array, default: [], allow_nil: false},
      skip_paths:               {type: Array, default: [], allow_nil: false},
      skip_importer_paths:      {type: Hash, default: {}, allow_nil: false},
      only_importer_paths:      {type: Hash, default: {}, allow_nil: false},

      cache_localization:       {type: Boolean, default: false},
      cache_manifest_formats:   {type: Array, default: []},

      watched_branches:         {type: Array, default: []},

      webhook_url:              {type: String, allow_nil: true}
  )

  extend SetNilIfBlank
  set_nil_if_blank :webhook_url

  include Slugalicious
  slugged :name

  extend LocaleField
  locale_field :base_locale, from: :base_rfc5646_locale
  locale_field :locale_requirements,
               from:   :targeted_rfc5646_locales,
               reader: ->(values) { values.inject({}) { |hsh, (k, v)| hsh[Locale.from_rfc5646(k)] = v; hsh } },
               writer: ->(values) { values.inject({}) { |hsh, (k, v)| hsh[k.rfc5646] = v; hsh } }

  validates :name,
            presence: true,
            length:   {maximum: 256}
  validates :repository_url,
            presence:   true,
            uniqueness: {case_sensitive: false}
  validates :api_key,
            presence: true
            #uniqueness: true,
            #length:     {is: 36},
            #format:     {with: /[0-9a-f\-]+/}

  validate :can_clone_repo, if: :validate_repo_connectivity
  validate :require_valid_locales_hash

  before_validation :create_api_key, on: :create
  before_validation { |obj| obj.skip_imports.reject!(&:blank?) }
  after_update :add_or_remove_pending_translations
  after_update :invalidate_manifests_and_localizations

  # Returns a `Git::Repository` proxy object that allows you to work with the
  # local checkout of this Project's repository. The repository will be checked
  # out if it hasn't been already.
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

  def repo
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
  # @raise [ActiveRecord::RecordNotFound] If an unknown SHA is given.

  def commit!(sha, options={})
    commit_object = repo { |repo| repo.object(sha) }
    commit_object ||= begin
      repo(&:fetch)
      repo { |repo| repo.object(sha) }
    end
    raise ActiveRecord::RecordNotFound, "No such commit #{sha}" unless commit_object

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

  def latest_commit
    commits.order('committed_at DESC').first
  end

  # @return [Array<Locale>] The locales this Project can be localized to.
  def targeted_locales() targeted_rfc5646_locales.keys.map { |l| Locale.from_rfc5646(l) } end

  # @return [Array<Locale>] The locales this Project *must* be localized to.
  def required_locales() targeted_rfc5646_locales.select { |_, req| req }.map(&:first).map { |l| Locale.from_rfc5646(l) } end

  def required_rfc5646_locales
    targeted_rfc5646_locales.select { |_, req| req }.map(&:first)
  end 

  def other_rfc5646_locales
    targeted_rfc5646_locales.select { |_, req| !req }.map(&:first)
  end 


  # Generates a new API key for the Project. Does not save the Project.
  def create_api_key() self.api_key = SecureRandom.uuid end

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

  def recalculate_commit_readiness
    ProjectReadinessRecalculator.perform_once id
  end

  # @private
  def inspect(default_behavior=false)
    return super() if default_behavior
    "#<#{self.class.to_s} #{id}: #{name}>"
  end

  private

  def repo_path
    @repo_path ||= REPOS_DIRECTORY.join(repo_directory)
  end

  def repo_directory
    @repo_dir ||= Digest::SHA1.hexdigest(repository_url) + '.git'
  end

  def clone_repo
    Git.clone repository_url, repo_directory, path: REPOS_DIRECTORY.to_s, mirror: true
  rescue Git::GitExecuteError
    Rails.logger.error $!
    return nil
  end

  def can_clone_repo
    errors.add(:repository_url, :unreachable) unless repo
  end

  def repo_mutex
    @repo_mutex = FileMutex.new(repo_path.to_s + '.lock')
  end

  def add_or_remove_pending_translations
    ProjectTranslationAdder.perform_once id
  end

  def invalidate_manifests_and_localizations
    keys = Shuttle::Redis.keys("manifest:#{id}:*") + Shuttle::Redis.keys("localize:#{id}:*")
    Shuttle::Redis.del(*keys) unless keys.empty?
  end

  def require_valid_locales_hash
    errors.add(:targeted_rfc5646_locales, :invalid) unless targeted_rfc5646_locales.keys.all? { |k| k.kind_of?(String) } &&
        targeted_rfc5646_locales.values.all? { |v| v == true || v == false }
  end
end
