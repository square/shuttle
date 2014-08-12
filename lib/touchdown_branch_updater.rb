class TouchdownBranchUpdater
  attr_reader :project
  attr_reader :working_repo
  attr_reader :touchdown_branch

  def initialize(project)
    @project = project
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
      @working_repo = working_repo
      @working_repo.fetch
      @touchdown_branch = project.touchdown_branch

      translated_commit = latest_translated_commit

      if translated_commit
        working_repo.update_ref("refs/heads/#{touchdown_branch}", translated_commit.sha)
        working_repo.reset_hard
        add_manifest_commit
        update_touchdown_branch
      else
        Rails.logger.info "[TouchdownBranchUpdater] Unable to find latest translated commit for #{project.inspect}"
      end
    end
  end

  private

  def valid_touchdown_branch?
    project.git? && project.watched_branches.present? && project.touchdown_branch.present?
  end

  def latest_translated_commit
    found_commit = nil
    offset = 0
    until found_commit
      return if offset >= 500
      branch = working_repo.object(project.watched_branches.first)
      return unless branch

      log = branch.log(50).skip(offset)
      break if log.size.zero?
      db_commits = project.commits.for_revision(log.map(&:sha)).where(ready: true).to_a
      log.each do |log_commit|
        if db_commits.detect { |dbc| dbc.revision == log_commit.sha }
          found_commit = log_commit
          break
        end
      end
      offset += log.size
    end
    found_commit
  end

  def add_manifest_commit
    head_commit         = working_repo.object('HEAD')
    format              = project.cache_manifest_formats.first
    manifest_directory  = if project.manifest_directory
                            Pathname.new(working_repo.dir.path).join(project.manifest_directory)
                          else
                            nil
                          end

    if format && manifest_directory
      Rails.logger.info "[TouchdownBranchUpdater] Adding translated manifest file for #{head_commit.sha}"
      shuttle_commit = Commit.for_revision(head_commit.sha).first
      compiler       = Compiler.new(shuttle_commit)
      # Not an actual Ruby File.  Actually Compiler::File object.
      file           = compiler.manifest(format)
      author_name    = Shuttle::Configuration.git.author.name
      author_email   = Shuttle::Configuration.git.author.email

      working_repo.checkout(touchdown_branch)

      # Create the manifest directory and write manifest file
      FileUtils::mkdir_p manifest_directory.to_s
      manifest_file = manifest_directory.join(file.filename).to_s
      File.write(manifest_file, file.content)

      working_repo.add(manifest_file)
      working_repo.commit('Adds translated manifest file from Shuttle', author: "#{author_name} <#{author_email}>")
    end
  end

  def update_touchdown_branch
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
