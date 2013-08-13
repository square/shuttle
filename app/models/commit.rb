# Copyright 2013 Square Inc.
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
#
# Properties
# ==========
#
# |                |                                                                                                          |
# |:---------------|:---------------------------------------------------------------------------------------------------------|
# | `committed_at` | The time this commit was made.                                                                           |
# | `message`      | The commit message.                                                                                      |
# | `ready`        | If `true`, all Keys under this Commit are marked as ready.                                               |
# | `revision`     | The SHA1 for this commit.                                                                                |
# | `loading`      | If `true`, there is at least one {BlobImporter} processing this Commit.                                  |
# | `priority`     | An administrator-set priority arbitrarily defined as a number between 0 (highest) and 3 (lowest).        |
# | `due_date`     | A date displayed to translators and reviewers informing them of when the Commit must be fully localized. |
#
# Metadata
# ========
#
# |                    |                                                                    |
# |:-------------------|:-------------------------------------------------------------------|
# | `description`      | A user-submitted description of why we are localizing this commit. |
# | `pull_request_url` | A user-submitted URL to the pull request that is being localized.  |

class Commit < ActiveRecord::Base
  extend RedisMemoize

  # @return [true, false] If `true`, does not perform an import after creating
  #   the Commit. Use this to avoid the overhead of making an HTTP request and
  #   spawning a worker for situations where Commits are being added in bulk.
  attr_accessor :skip_import

  belongs_to :project, inverse_of: :commits
  belongs_to :user, inverse_of: :commits
  has_and_belongs_to_many :keys, -> { uniq }
  has_many :translations, through: :keys

  include HasMetadataColumn
  has_metadata_column(
      description:      {allow_nil: true},
      pull_request_url: {allow_nil: true}
  )

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

  attr_readonly :project_id, :revision_raw, :message, :committed_at

  extend GitObjectField
  git_object_field :revision,
                   git_type:        :commit,
                   repo:            ->(c) { c.project.try!(:repo) },
                   repo_must_exist: true,
                   scope:           :for_revision

  extend SetNilIfBlank
  set_nil_if_blank :description, :due_date

  before_validation :load_message, on: :create
  before_validation(on: :create) do |obj|
    obj.message = obj.message.truncate(256) if obj.message
  end

  after_commit(on: :create) do |commit|
    CommitImporter.perform_once(commit.id) unless commit.skip_import
  end
  after_commit :compile_and_cache_or_clear, on: :update
  after_destroy { |c| Commit.flush_memoizations c.id }

  attr_readonly :revision, :message

  scope :by_priority_and_due_date, -> { order('due_date ASC, priority ASC') }
  scope :with_sha_prefix, lambda { |sha| where("encode(revision_raw, 'hex') like ?", "#{sha}%") }

  # @private
  def to_param() revision end

  # Calculates the value of the `ready` field and saves the record.

  def recalculate_ready!
    ready = !keys.where(ready: false).exists?
    self.ready = ready
    save!
    compile_and_cache_or_clear(ready)
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
  # @raise [CommitNotFoundError] If the commit could not be found in the Git
  #   repository.

  def import_strings(options={})
    raise CommitNotFoundError, "Commit no longer exists: #{revision}" unless commit!

    blobs = project.blobs.includes(:project) # preload blobs for performance

    # add us as one of the workers, to prevent the commit from prematurely going
    # ready; let's just invent a job ID for us
    job_id = SecureRandom.uuid
    add_worker! job_id

    # clear out existing keys so that we can import all new keys
    keys.clear unless options[:locale]
    # perform the recursive import
    import_tree commit!.gtree, '', options.merge(blobs: blobs)

    # this will also kick of stats recalculation for inline imports
    remove_worker! job_id
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
  # @return [Git::Object::Commit, nil] The commit object.

  def commit!
    project.repo do |r|
      r.object(revision) || (r.fetch && r.object(revision))
    end
  end

  # @return [String, nil] The URL to this commit on GitHub or GitHub Enterprise,
  #   or `nil` if the URL could not be determined.

  def github_url
    if project.repository_url =~ /^git@github\.com:([^\/]+)\/(.+)\.git$/ ||
        project.repository_url =~ /https:\/\/\w+@github\.com\/([^\/]+)\/(.+)\.git/ ||
        project.repository_url =~ /git:\/\/github\.com\/([^\/]+)\/(.+)\.git/ # GitHub
      "https://github.com/#{$1}/#{$2}/commit/#{revision}"
    end
  end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :github_url << :revision

    options[:except] = Array.wrap(options[:except])
    options[:except] << :revision_raw

    super options
  end

  # @return [Fixnum] The number of approved Translations across all required
  #   under this Commit.

  def translations_done
    translations.not_base.where(approved: true, rfc5646_locale: project.required_locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_done

  # @return [Fixnum] The number of Translations across all required locales
  #   under this Commit.

  def translations_total
    translations.not_base.where(rfc5646_locale: project.required_locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_total

  # @return [Float] The fraction of Translations under this Commit that are
  #   approved, across all required locales.

  def fraction_done
    translations_done/translations_total.to_f
  end

  # @return [Fixnum] The total number of translatable base strings applying to
  #   this Commit.

  def strings_total
    keys.count
  end
  redis_memoize :strings_total

  # Calculates the total number of Translations that have not yet been
  # translated.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of Translations.

  def translations_new(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where(translated: false, rfc5646_locale: locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_new

  # Calculates the total number of Translations that have not yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of Translations.

  def translations_pending(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where('approved IS NOT TRUE').
        where(translated: true, rfc5646_locale: locales.map(&:rfc5646)).count
  end
  redis_memoize :translations_pending

  # Calculates the total number of words across all Translations that have not
  # yet been approved.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy.

  def words_pending(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where('approved IS NOT TRUE').
        where(translated: true, rfc5646_locale: locales.map(&:rfc5646)).sum(:words_count)
  end
  redis_memoize :words_pending

  # Calculates the total number of words across all Translations that have not
  # yet been translations.
  #
  # @param [Array<Locale>] locales If provided, a locale to limit the sum to.
  #   Defaults to all required locales.
  # @return [Fixnum] The total number of words in the Translations' source copy.

  def words_new(*locales)
    locales = project.required_locales if locales.empty?
    translations.not_base.where(translated: false, rfc5646_locale: locales.map(&:rfc5646)).sum(:words_count)
  end
  redis_memoize :words_new

  # Adds a worker to the loading list. This commit, if not already loading,
  # will be marked as loading until this and all other added workers call
  # {#remove_worker!}.
  #
  # @param [String] jid A unique identifier for this worker.

  def add_worker!(jid)
    self.loading = true
    save!
    Shuttle::Redis.sadd "import:#{revision}", jid
  end

  # Removes a worker from the loading list. This Commit will not be marked as
  # loading if this was the last worker. Also recalculates Commit statistics if
  # this was the last worker.
  #
  # @param [String] jid A unique identifier for this worker.
  # @see #add_worker!

  def remove_worker!(jid)
    loading_was = self.loading

    Shuttle::Redis.srem "import:#{revision}", jid
    loading = (Shuttle::Redis.scard("import:#{revision}") > 0)
    self.loading = loading
    save!

    update_stats_at_end_of_loading if loading_was && !loading
  end

  # Removes all workers from the loading list, marks the Commit as not loading,
  # and recalculates Commit statistics if the Commit was previously loading.
  # This method should be used to fix "stuck" Commits.

  def clear_workers!
    Shuttle::Redis.del "import:#{revision}"
    if loading?
      self.loading = false
      save!
      update_stats_at_end_of_loading if loading_was && !loading
    end
  end

  def all_translations_entered_for_locale?(locale)
    translations.not_base.where(rfc5646_locale: locale.rfc5646, translated: false).count == 0
  end

  def all_translations_approved_for_locale?(locale)
    translations.not_base.where(rfc5646_locale: locale.rfc5646, approved: false).count == 0
  end

  # @private
  def redis_memoize_key() to_param end

  # @return [true, false] True if there are cached Sidekiq job IDs of
  #   in-progress BlobImporters that do not actually exist anymore.

  def broken?
    cached_jids = Shuttle::Redis.smembers("import:#{revision}")
    return false if cached_jids.empty?
    actual_jids = self.class.workers.map { |w| w['jid'] }
    (cached_jids & actual_jids).empty? # none of the cached JIDs actually exist anymore
  end

  # @private Shanghai'd from Sidekiq::Web
  def self.workers
    Sidekiq.redis do |conn|
      conn.smembers('workers').map do |w|
        msg = conn.get("worker:#{w}")
        msg ? Sidekiq.load_json(msg) : nil
      end.compact
    end
  end

  private

  def load_message
    self.message ||= commit!.message
    true
  end

  def compile_and_cache_or_clear(force=false)
    return unless force || ready_changed?

    # clear out existing cache entries if present
    Exporter::Base.implementations.each do |exporter|
      Shuttle::Redis.del ManifestPrecompiler.new.key(self, exporter.request_mime)
    end
    Shuttle::Redis.del LocalizePrecompiler.new.key(self)

    # if ready, generate new cache entries
    if ready?
      LocalizePrecompiler.perform_once(id) if project.cache_localization?
      project.cache_manifest_formats.each do |format|
        ManifestPrecompiler.perform_once id, format
      end
    end
  end

  def import_tree(tree, path, options={})
    tree.blobs.each do |name, blob|
      blob_path   = "#{path}/#{name}"
      blob_object = if options[:blobs]
                      begin
                        options[:blobs].detect { |b| b.sha == blob.sha } || project.blobs.with_sha(blob.sha).create!(sha: blob.sha)
                      rescue ActiveRecord::RecordNotUnique
                        project.blobs.with_sha(blob.sha).find_or_create!(sha: blob.sha)
                      end
                    else
                      project.blobs.with_sha(blob.sha).find_or_create!(sha: blob.sha)
                    end

      imps = Importer::Base.implementations.reject { |imp| project.skip_imports.include?(imp.ident) }
      imps.each do |importer|
        importer = importer.new(blob_object, blob_path, self)

        Shuttle::Redis.del("keys_for_blob:#{importer.class.ident}:#{blob.sha}") if options[:force]

        if importer.skip?(options[:locale])
          #Importer::SKIP_LOG.info "commit=#{revision} blob=#{blob.sha} path=#{blob_path} importer=#{importer.class.ident} #skip? returned true for #{options[:locale].inspect}"
          next
        end

        if options[:inline]
          BlobImporter.new.perform importer.class.ident, project.id, blob.sha, blob_path, id, options[:locale].try!(:rfc5646)
        else
          add_worker! BlobImporter.perform_once(importer.class.ident, project.id, blob.sha, blob_path, id, options[:locale].try!(:rfc5646))
        end
      end
    end

    tree.trees.each do |name, subtree|
      import_tree subtree, "#{path}/#{name}", options
    end
  end

  def update_stats_at_end_of_loading(should_recalculate_affected_commits=false)
    # the readiness hooks were all disabled, so now we need to go through and
    # calculate readiness and stats. since we could have altered the readiness
    # of other commits associated with translations we just imported, we need to
    # do this for all commits that could potentially be affected

    # first we do it for this commit, so we can set loading to false ASAP
    CommitStatsRecalculator.new.perform id

    # then we do it for everyone else
    project.commits.find_each do |commit|
      next if commit.id == id
      CommitStatsRecalculator.perform_once commit.id, should_recalculate_affected_commits
    end
  end
end
