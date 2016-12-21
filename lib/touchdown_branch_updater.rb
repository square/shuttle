 class TouchdownBranchUpdater
  attr_reader :project
  attr_reader :source_branch
  attr_reader :git_author_name
  attr_reader :git_author_email

  delegate :touchdown_branch, :watched_branches, to: :project

  def initialize(project)
    @project = project
    @source_branch = watched_branches.first
    @git_author_name = Shuttle::Configuration.app.git.author.name
    @git_author_email = Shuttle::Configuration.app.git.author.email
  end

  # Updates the `touchdown_branch` head to be the latest translated commit in
  # the first `watched_branches` branch. Does nothing if either of those fields
  # are not set, or if repo is nil.
  #
  # If manifest_directory is also set, it will also create a new commit containing
  # the translated manifest in the specified manifest_directory.  This commit
  # will be pushed up as well to the touchdown branch.
  def update
    return unless valid_touchdown_branch?
    project.working_repo do |working_repo|
      working_repo.fetch('origin')

      unless working_repo.branches["origin/#{touchdown_branch}"]
        Rails.logger.info "[TouchdownBranchUpdater] Touchdown branch #{touchdown_branch} doesn't exist in #{project.inspect}"
        return
      end

      if working_repo.branches[touchdown_branch]
        working_repo.reset("origin/#{touchdown_branch}", :hard)
      else
        working_repo.branches.create(touchdown_branch, "origin/#{touchdown_branch}")
      end

      unless working_repo.branches["origin/#{source_branch}"]
        Rails.logger.info "[TouchdownBranchUpdater] Watched branch #{source_branch} doesn't exist in #{project.inspect}"
        return
      end

      if working_repo.branches[source_branch]
        working_repo.checkout(source_branch)
        working_repo.reset("origin/#{source_branch}", :hard)
      else
        working_repo.branches.create(source_branch, "origin/#{source_branch}")
      end

      translated_commit = latest_commit_in_source_branch(working_repo)
      if translated_commit.nil?
        Rails.logger.info "[TouchdownBranchUpdater] Unable to find latest translated commit for #{project.inspect}"
        return
      end

      Rails.logger.info "[TouchdownBranchUpdater] Found the latest commit in source branch: #{translated_commit.oid}"

      if touchdown_branch_changed?(translated_commit, working_repo)
        Rails.logger.info "[TouchdownBranchUpdater] Found that touchdown branch has changed"
        working_repo.checkout(touchdown_branch)
        working_repo.checkout_tree(translated_commit, :strategy => :force)
        working_repo.references.update("refs/heads/#{touchdown_branch}", translated_commit.oid)
        add_manifest_commit(working_repo)
        update_touchdown_branch(working_repo)
      else
        Rails.logger.info "[TouchdownBranchUpdater] Tracked branch has not changed. Touchdown branch was not updated."
      end
    end
  end

  private

  def valid_touchdown_branch?
    project.git? && watched_branches.present? && touchdown_branch.present?
  end

  def valid_manifest_settings?
    project.default_manifest_format.present? && project.manifest_directory.present?
  end

  def touchdown_branch_changed?(translated_commit, working_repo)
    branch = working_repo.branches[touchdown_branch]
    return true unless branch
    if valid_manifest_settings?
      return true unless branch.target.author[:name] == git_author_name
    end
    # Find the first commit that was not created by Shuttle
    walker = Rugged::Walker.new(working_repo)
    walker.push(branch.target_id)
    current_touchdown_commit = walker.detect { |c| c.author[:name] != git_author_name }

    # Only update the touchdown branch if the latest non-shuttle touchdown commit
    # is not equal to the latest translated commit
    current_touchdown_commit.oid != translated_commit.oid
  end

  def latest_commit_in_source_branch(working_repo)
    head_commit = working_repo.branches[source_branch].target
    db_commit = project.commits.for_revision(head_commit.oid).first
    db_commit.try(:ready?) ? head_commit : nil
  end

  def add_manifest_commit(working_repo)
    if valid_manifest_settings?
      head_commit         = working_repo.branches[touchdown_branch].target
      format              = project.default_manifest_format
      manifest_directory  = Pathname.new(working_repo.workdir).join(project.manifest_directory)
      Rails.logger.info "[TouchdownBranchUpdater] Adding translated manifest file for #{head_commit.oid}"
      shuttle_commit = Commit.for_revision(head_commit.oid).first
      compiler       = Compiler.new(shuttle_commit)
      # Not an actual Ruby File.  Actually Compiler::File object.
      file           = compiler.manifest(format)
      manifest_filename = project.manifest_filename || file.filename

      working_repo.checkout(touchdown_branch)

      # Create the manifest directory and write manifest file
      FileUtils::mkdir_p manifest_directory.to_s

      oid = working_repo.write(file.content, :blob)
      index = working_repo.index
      index.read_tree(working_repo.head.target.tree)
      index.add(path: File.join(project.manifest_directory, manifest_filename), oid: oid, :mode => 0100644)
      index.write

      options = {}
      options[:tree] = index.write_tree(working_repo)

      options[:author] = { email: git_author_email, name: git_author_name, time: Time.now }
      options[:committer] = { email: git_author_email, name: git_author_name, time: Time.now }
      options[:message] ||= 'Adds translated manifest file from Shuttle'
      options[:parents] = working_repo.empty? ? [] : [ working_repo.head.target ].compact
      options[:update_ref] = 'HEAD'

      Rugged::Commit.create(working_repo, options)
      working_repo.checkout(touchdown_branch, strategy: :force)
    end
  end

  def update_touchdown_branch(working_repo)
    Rails.logger.info "[TouchdownBranchUpdater] Updating #{project.inspect} branch #{touchdown_branch} to #{working_repo.rev_parse('HEAD').oid}"
    begin
      Timeout::timeout(1.minute) do
        working_repo.remotes['origin'].push(["+refs/heads/#{touchdown_branch}"], credentials: project.credentials)
      end
    rescue Timeout::Error
      Rails.logger.error "[TouchdownBranchUpdater] Timed out on updating touchdown branch for #{project.inspect}"
    end
  end
end
