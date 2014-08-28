require 'spec_helper'

describe TouchdownBranchUpdater do
  let(:project) do
    project = FactoryGirl.create(:project, :light)
    system 'git', 'push', project.repository_url, ':refs/heads/translated'
    project
  end

  let(:head_revision) { 'fb355bb396eb3cf66e833605c835009d77054b71' }
  let(:parent_revision) { '67adce6e5e7e2cae5621b8e86d4ebdd20b5ce264' }

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
      it "advances the touchdown branch to the watched branch commit if it is translated" do
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

      it "does nothing if the head of the watched branch is not translated" do
        project.watched_branches = %w(master)
        project.touchdown_branch = 'translated'

        parent_commit = project.commit!(parent_revision)
        parent_commit.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
        CommitStatsRecalculator.new.perform(parent_commit.id)
        expect(parent_commit.reload).to be_ready

        head_commit = project.commit!(head_revision)
        expect(head_commit.reload).to_not be_ready

        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
      end

      it "does nothing if the head of the watched branch has not changed" do
        project.watched_branches = %w(master)
        project.touchdown_branch = 'translated'

        c = project.commit!(head_revision)
        c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
        CommitStatsRecalculator.new.perform(c.id)
        expect(c.reload).to be_ready

        # Mock to make it seem as if the working_repo's head of translated has not changed.
        working_repo = double('working_repo').as_null_object
        head_commit = project.working_repo.object(head_revision)
        allow(working_repo).to receive(:object).and_return(head_commit)
        allow(project).to receive(:working_repo).and_yield(working_repo)

        TouchdownBranchUpdater.new(project).update
        expect(working_repo).to_not have_received(:push)
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

      context "already created manifest" do
        before do
          project.watched_branches = %w(master)
          project.touchdown_branch = 'translated'
          project.cache_manifest_formats = %w(yaml)
          project.manifest_directory = 'nonexist/directory'

          c = project.commit!(head_revision)
          c.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.skip_readiness_hooks = true; t.save }
          CommitStatsRecalculator.new.perform(c.id)
          c.reload
          TouchdownBranchUpdater.new(project).update
        end

        it "does not attempt to push another commit if manifest is already there" do
          # Mock to make it seem as if the working_repo's head of translated has not changed.
          working_repo = double('working_repo').as_null_object
          source_branch = project.watched_branches.first
          touchdown_branch = project.touchdown_branch

          translated_commit = project.working_repo.object(source_branch)
          touchdown_commit = project.working_repo.object(touchdown_branch)

          allow(working_repo).to receive(:object).and_return(translated_commit)
          allow(working_repo).to receive(:object).with(touchdown_branch).and_return(touchdown_commit)
          allow(project).to receive(:working_repo).and_yield(working_repo)

          TouchdownBranchUpdater.new(project).update
          expect(working_repo).to_not have_received(:push)
        end
      end
    end
  end
end

