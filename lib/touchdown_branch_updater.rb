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
      # Set the user and email of the git repository 
      working_repo.config('user.name', git_author_name)
      working_repo.config('user.email', git_author_email)

      working_repo.fetch
      working_repo.reset_hard # cleanup any lingering changes

      touchdown_branch_git_obj = working_repo.object("origin/#{touchdown_branch}")
      unless touchdown_branch_git_obj
        Rails.logger.info "[TouchdownBranchUpdater] Touchdown branch #{touchdown_branch} doesn't exist in #{project.inspect}"
        return
      end

      working_repo.update_ref("refs/heads/#{touchdown_branch}", touchdown_branch_git_obj.sha)
      working_repo.reset_hard # cleanup any lingering changes
      working_repo.checkout(source_branch)
      working_repo.reset_hard("origin/#{source_branch}")

      translated_commit = latest_commit_in_source_branch(working_repo)
      if translated_commit.nil?
        Rails.logger.info "[TouchdownBranchUpdater] Unable to find latest translated commit for #{project.inspect}"
        return
      end

      Rails.logger.info "[TouchdownBranchUpdater] Found the latest commit in source branch: #{translated_commit.sha}"

      if touchdown_branch_changed?(translated_commit, working_repo)
        Rails.logger.info "[TouchdownBranchUpdater] Found that touchdown branch has changed"
        # Updates the tip of the touchdown branch to the specified SHA
        working_repo.update_ref("refs/heads/#{touchdown_branch}", translated_commit.sha)
        # git reset --hard is needed here because updating the ref of a separate branch will cause 
        # the reset changes to populate the untracked changes
        working_repo.reset_hard
        add_manifest_commit(working_repo)
        update_touchdown_branch(working_repo)
      else
        Rails.logger.info "[TouchdownBranchUpdater] Tracked branch has not changed.  Touchdown branch was not updated."
      end
    end
  rescue RuntimeError => e
    Rails.logger.error "[TouchdownBranchUpdater] Unable to update touchdown branch due to git runtime issues"
    Rails.logger.error e
  end

  private

  def valid_touchdown_branch?
    project.git? && watched_branches.present? && touchdown_branch.present?
  end

  def valid_manifest_settings?
    project.default_manifest_format.present? && project.manifest_directory.present?
  end 

  def touchdown_branch_changed?(translated_commit, working_repo)
    branch = working_repo.object(touchdown_branch)
    return true unless branch
    if valid_manifest_settings?
      return true unless branch.author.name == git_author_name
    end 

    # Find the first commit that was not created by Shuttle
    current_touchdown_commit = branch.log(50).detect { |c| c.author.name != git_author_name }
    Rails.logger.info "[TouchdownBranchUpdater] Current touchdown commit: #{current_touchdown_commit.sha}"

    # Only update the touchdown branch if the latest non-shuttle touchdown commit
    # is not equal to the latest translated commit
    current_touchdown_commit.sha != translated_commit.sha
  end

  def latest_commit_in_source_branch(working_repo)
    head_commit = working_repo.object(source_branch)
    db_commit = project.commits.for_revision(head_commit.sha).first
    db_commit.try(:ready?) ? head_commit : nil
  end

  def add_manifest_commit(working_repo)
    if valid_manifest_settings?
      head_commit         = working_repo.object(touchdown_branch)
      format              = project.default_manifest_format
      manifest_directory  = Pathname.new(working_repo.dir.path).join(project.manifest_directory)
      Rails.logger.info "[TouchdownBranchUpdater] Adding translated manifest file for #{head_commit.sha}"
      shuttle_commit = Commit.for_revision(head_commit.sha).first
      compiler       = Compiler.new(shuttle_commit)
      # Not an actual Ruby File.  Actually Compiler::File object.
      file           = compiler.manifest(format)
      manifest_filename = project.manifest_filename || file.filename

      working_repo.checkout(touchdown_branch)

      # Create the manifest directory and write manifest file
      FileUtils::mkdir_p manifest_directory.to_s
      manifest_file = manifest_directory.join(manifest_filename).to_s
      File.write(manifest_file, file.content)

      working_repo.add(manifest_file)
      working_repo.commit('Adds translated manifest file from Shuttle')
    end
  end

  def update_touchdown_branch(working_repo)
    Rails.logger.info "[TouchdownBranchUpdater] Updating #{project.inspect} branch #{touchdown_branch} to #{working_repo.object('HEAD').sha}"
    begin
      Timeout::timeout(1.minute) do
        working_repo.push('origin', touchdown_branch, force: true)
      end
    rescue Timeout::Error
      Rails.logger.error "[TouchdownBranchUpdater] Timed out on updating touchdown branch for #{project.inspect}"
    end
  end
end
