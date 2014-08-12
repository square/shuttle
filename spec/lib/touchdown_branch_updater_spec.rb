require 'spec_helper'

describe TouchdownBranchUpdater do
  let(:project) do
    project = FactoryGirl.create(:project, :light)
    system 'git', 'push', project.repository_url, ':refs/heads/translated'
    project
  end

  let(:head_revision) { '67adce6e5e7e2cae5621b8e86d4ebdd20b5ce264' }

  describe "#update" do
    context "invalid touchdown branch" do
      it "returns immediately if missing watched_branches and touchdown_branch" do
        project.watched_branches = []
        project.touchdown_branch = nil
        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
      end
    end

    context "non-existant watched branch" do
      it "gracefully exits if the first watched branch doesn't exist" do
        project.watched_branches = %w(nonexistent)
        project.touchdown_branch = 'translated'

        c = project.commit!(head_revision)
        c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
        CommitStatsRecalculator.new.perform(c.id)
        expect(c.reload).to be_ready

        expect { TouchdownBranchUpdater.new(project).update }.not_to raise_error
      end
    end

    context "valid touchdown branch" do
      it "advances the touchdown branch to the most recently translated watched branch commit" do
        project.watched_branches = %w(master)
        project.touchdown_branch = 'translated'

        c = project.commit!(head_revision)
        c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
        CommitStatsRecalculator.new.perform(c.id)
        expect(c.reload).to be_ready

        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql(head_revision)
      end

      it "does nothing if none of the commits in the watched branch are translated" do
        project.watched_branches = %w(master)
        project.touchdown_branch = 'translated'

        c = project.commit!(head_revision)
        expect(c).not_to be_ready

        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
      end

      it "logs an error if updating the touchdown branch takes longer than 1 minute" do
        project.watched_branches = %w(master)
        project.touchdown_branch = 'translated'

        allow(project.working_repo).to receive('push').and_raise(Timeout::Error)

        c = project.commit!(head_revision)
        c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
        CommitStatsRecalculator.new.perform(c.id)

        expect(c.reload).to be_ready
        expect(Rails.logger).to receive(:error).with("[TouchdownBranchUpdater] Timed out on updating touchdown branch for #{project.inspect}")

        TouchdownBranchUpdater.new(project).update
      end
    end

    context "valid manifest directory and touchdown branch" do
      context "existing manifest directory" do
        before do
          project.watched_branches = %w(master)
          project.touchdown_branch = 'translated'
          project.cache_manifest_formats = %w(yaml)
          project.manifest_directory = 'config/locales'

          c = project.commit!(head_revision)
          c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
          CommitStatsRecalculator.new.perform(c.id)
          c.reload
        end

        it "pushes a new commit with the manifest to the specified manifest directory" do
          TouchdownBranchUpdater.new(project).update
          expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
            to_not eql(head_revision)
        end

        it "pushes a new commit with the correct author" do
          TouchdownBranchUpdater.new(project).update
          expect(project.working_repo.object(project.touchdown_branch).author.name).to eql(Shuttle::Configuration.git.author.name)
          expect(project.working_repo.object(project.touchdown_branch).author.email).to eql(Shuttle::Configuration.git.author.email)
        end

        it "creates a manifest file in the specified directory" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory, 'manifest.yaml')
          expect(File.exist?(manifest_filepath)).to be_true
        end

        it "creates a valid manifest file" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory, 'manifest.yaml')
          expect(File.read(manifest_filepath)).to include('de-DE:')
        end
      end

      context "non-existant manifest directory" do
        before do
          project.watched_branches = %w(master)
          project.touchdown_branch = 'translated'
          project.cache_manifest_formats = %w(yaml)
          project.manifest_directory = 'nonexist/directory'

          c = project.commit!(head_revision)
          c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
          CommitStatsRecalculator.new.perform(c.id)
          c.reload
        end

        it "does not fail if the manifest directory doesn't exist if it doesn't already exist" do
          expect { TouchdownBranchUpdater.new(project).update }.to_not raise_error
        end

        it "creates the non-existant directory and a manifest file in it" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory)
          expect(File.exist?(manifest_filepath)).to be_true
        end
      end
    end
  end
end

