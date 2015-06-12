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

require 'spec_helper'

describe TouchdownBranchUpdater do
  def commit_and_translate(project, revision)
    c = project.commit!(revision)
    c.reload.translations.each { |t| t.copy = t.source_copy; t.approved = true; t.save! }
    Key.batch_recalculate_ready!(c)
    c.recalculate_ready!
    expect(c).to be_ready
  end

  let(:project) do
    project = FactoryGirl.create(:project, :light)
    system 'git', 'push', project.repository_url, ':refs/heads/translated'
    project.update! touchdown_branch: 'translated'
    project
  end

  let(:head_revision) { 'fb355bb396eb3cf66e833605c835009d77054b71' }
  let(:parent_revision) { '67adce6e5e7e2cae5621b8e86d4ebdd20b5ce264' }
  let(:grandparent_revision) { 'a26f7f6a09aa362ff777c0bec11fa084e66efe64' }

  before do
    project.working_repo.update_ref("refs/heads/#{project.touchdown_branch}", parent_revision)
    project.working_repo.update_ref("refs/remotes/origin/#{project.touchdown_branch}", parent_revision)
  end

  describe "#update" do
    context "invalid touchdown branch" do
      it "returns immediately if missing watched_branches and touchdown_branch" do
        project.update! watched_branches: [], touchdown_branch: nil
        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
      end
    end

    context "non-existant watched branch" do
      it "gracefully exits if the first watched branch doesn't exist" do
        project.update! watched_branches: %w(nonexistent)
        commit_and_translate(project, head_revision)
        expect { TouchdownBranchUpdater.new(project).update }.not_to raise_error
      end
    end

    context "valid touchdown branch" do
      it "advances the touchdown branch to the watched branch commit if it is translated" do
        project.update! watched_branches: %w(master)
        commit_and_translate(project, head_revision)

        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql(head_revision)
      end

      it "does nothing if the head of the watched branch is not translated" do
        project.update! watched_branches: %w(master)
        commit_and_translate(project, parent_revision)

        head_commit = project.commit!(head_revision)
        expect(head_commit.reload).to_not be_ready

        TouchdownBranchUpdater.new(project).update
        expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
          to eql('translated')
      end

      it "does nothing if the head of the watched branch has not changed" do
        project.update! watched_branches: %w(master)
        commit_and_translate(project, head_revision)
        TouchdownBranchUpdater.new(project).update

        # Running touchdown branch updater should not send another push 
        working_repo = project.working_repo
        allow(project).to receive(:working_repo).and_yield(working_repo)
        expect(working_repo).to_not receive(:push)
        TouchdownBranchUpdater.new(project).update
      end

      it "logs an info and doesn't raise an error if the touchdown branch doesn't exist" do
        project.update! watched_branches: %w(master), touchdown_branch: 'doesntexist'
        commit_and_translate(project, head_revision)

        expect(Rails.logger).to receive(:info).with("[TouchdownBranchUpdater] Touchdown branch doesntexist doesn't exist in #{project.inspect}")
        expect { TouchdownBranchUpdater.new(project).update }.to_not raise_error
      end

      it "logs an error if updating the touchdown branch takes longer than 1 minute" do
        project.update! watched_branches: %w(master)
        commit_and_translate(project, head_revision)

        allow(project.working_repo).to receive('push').and_raise(Timeout::Error)
        expect(Rails.logger).to receive(:error).with("[TouchdownBranchUpdater] Timed out on updating touchdown branch for #{project.inspect}")
        TouchdownBranchUpdater.new(project).update
      end
    end

    context "valid manifest directory and touchdown branch" do
      context "existing manifest directory" do
        before do
          project.update! watched_branches: %w(master), default_manifest_format: 'yaml', manifest_directory: 'config/locales'
          commit_and_translate(project, head_revision)
        end

        it "pushes a new commit with the manifest to the specified manifest directory" do
          TouchdownBranchUpdater.new(project).update
          expect(`git --git-dir=#{Shellwords.escape project.repository_url} rev-parse translated`.chomp).
            to_not eql(head_revision)
        end

        it "pushes a new commit with the correct author" do
          TouchdownBranchUpdater.new(project).update
          expect(project.working_repo.object(project.touchdown_branch).author.name).to eql(Shuttle::Configuration.app.git.author.name)
          expect(project.working_repo.object(project.touchdown_branch).author.email).to eql(Shuttle::Configuration.app.git.author.email)
        end

        it "creates a manifest file in the specified directory" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory, 'manifest.yaml')
          expect(File.exist?(manifest_filepath)).to be_truthy
        end

        it "creates a valid manifest file" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory, 'manifest.yaml')
          expect(File.read(manifest_filepath)).to include('de-DE:')
        end

        context "source branch (green) is behind master and touchdown branch (translated) is behind source branch" do
          before do
            # head_revision is translated, but parent_revision & grandparent_revision is not.
            source_branch = 'green'
            project.update! watched_branches: [source_branch, 'master']
            project.working_repo.update_ref("refs/heads/master", head_revision)
            project.working_repo.checkout('master')
            project.working_repo.push('origin', 'master', force: true)
            project.working_repo.update_ref("refs/heads/#{project.touchdown_branch}", grandparent_revision)
            project.working_repo.checkout(project.touchdown_branch)
            project.working_repo.push('origin', project.touchdown_branch, force: true)
            project.working_repo.update_ref("refs/heads/green", parent_revision)
            project.working_repo.checkout(source_branch)
            project.working_repo.push('origin', source_branch, force: true)
          end

          it "doesn't update touchdown branch if the tip of first watched branch (green) is not translated" do # since the tip of green is not translated
            TouchdownBranchUpdater.new(project).update

            project.working_repo.checkout(project.touchdown_branch)
            project.working_repo.pull('origin', project.touchdown_branch)
            expect(project.working_repo.object(project.touchdown_branch).sha).to eql(grandparent_revision)
          end

          it "updates the touchdown branch to the tip of first watched branch if the tip of first watched branch is transalted; adds a new commit with the manifest file" do
            commit_and_translate(project, parent_revision)

            TouchdownBranchUpdater.new(project).update

            project.working_repo.checkout(project.touchdown_branch)
            project.working_repo.pull('origin', project.touchdown_branch)
            expect(project.working_repo.log[1].sha).to eql(parent_revision)
            expect(project.working_repo.log[0].author.name).to eql(Shuttle::Configuration.app.git.author.name)
            expect(project.working_repo.log[0].author.email).to eql(Shuttle::Configuration.app.git.author.email)
          end
        end
      end

      context "non-existant manifest directory" do
        before do
          project.update! watched_branches: %w(master), default_manifest_format: 'yaml', manifest_directory: 'nonexist/directory'
          commit_and_translate(project, head_revision)
        end

        it "does not fail if the manifest directory doesn't exist if it doesn't already exist" do
          expect { TouchdownBranchUpdater.new(project).update }.to_not raise_error
        end

        it "creates the non-existant directory and a manifest file in it" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory)
          expect(File.exist?(manifest_filepath)).to be_truthy
        end
      end

      context "specified manifest filename" do
        before do
          project.update! watched_branches: %w(master), default_manifest_format: 'yaml', manifest_directory: 'config/locales', manifest_filename: 'zzz_manifest.yaml'
          commit_and_translate(project, head_revision)
        end

        it "creates a manifest file in the specified directory" do
          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory, 'zzz_manifest.yaml')
          expect(File.exist?(manifest_filepath)).to be_truthy
        end
      end

      context "previous touchdown branch already at tip" do
        before do
          # Set the touchdown branch to the tip
          project.update! watched_branches: %w(master)
          commit_and_translate(project, head_revision)

          TouchdownBranchUpdater.new(project).update
        end

        it "should still create a new commit with the manifest file at the tip" do
          project.update! default_manifest_format: 'yaml', manifest_directory: 'config/locales'

          TouchdownBranchUpdater.new(project).update
          manifest_filepath = Pathname.new(project.working_repo.dir.path).join(project.manifest_directory, 'manifest.yaml')
          expect(File.exist?(manifest_filepath)).to be_truthy
        end
      end

      context "already created manifest" do
        before do
          project.update! watched_branches: %w(master), default_manifest_format: 'yaml', manifest_directory: 'nonexist/directory'
          commit_and_translate(project, head_revision)
          TouchdownBranchUpdater.new(project).update
        end

        it "does not attempt to push another commit if manifest is already there" do
          working_repo = project.working_repo
          allow(project).to receive(:working_repo).and_yield(working_repo)
          expect(working_repo).to_not receive(:push)
          TouchdownBranchUpdater.new(project).update
        end
      end
    end
  end
end

