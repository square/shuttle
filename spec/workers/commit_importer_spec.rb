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

describe CommitImporter do
  context "[unit-tests]" do
    describe "#perform" do
      context "[rescue Git::CommitNotFoundError]" do
        it "adds import errors to commit when commit importer fails due to a Git::CommitNotFoundError" do
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_return(nil)
          project = FactoryGirl.create(:project)
          commit = FactoryGirl.create(:commit, revision: "abc123", project: project)

          expect { CommitImporter.new.perform(commit.id) }.to_not raise_error
          expect(commit.reload.import_errors).to eql([["Git::CommitNotFoundError", "Commit not found in git repo: abc123 (failed in CommitImporter for commit_id #{commit.id})"]])
        end
      end
    end
  end

  context "[integration-tests]" do
    describe "#perform" do
      context "[rescue Git::CommitNotFoundError]" do
        def expect_to_send_import_errors_email(expected_errors)
          expect(ActionMailer::Base.deliveries.size).to eql(1)
          mail = ActionMailer::Base.deliveries.first

          expect(mail.to).to eql(["yunus@squareup.com"])
          expect(mail.subject).to eql("[Shuttle] Error(s) occurred during the import")
          expected_errors.each do |err_class, err_message|
            expect(mail.body).to include("#{err_class} - #{err_message}")
          end
        end

        before :each do
          @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)
        end

        it "records all import errors and sends an email after the import if errors occured during the import (such as in BlobImporter or CommitKeyCreator)" do
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_call_original
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).with("88e5b52732c23a4e33471d91cf2281e62021512a").and_return(nil) # fake a Git::BlobNotFoundError in CommitImporter
          allow_any_instance_of(Commit).to receive(:skip_key?).with("how_are_you").and_raise(Git::CommitNotFoundError, "fake_sha") # fake a CommitNotFoundError error in CommitKeyCreator failure

          ActionMailer::Base.deliveries.clear
          commit  = @project.commit!('e5f5704af3c1f84cf42c4db46dcfebe8ab842bde')

          blob_not_found = commit.blobs.with_sha("88e5b52732c23a4e33471d91cf2281e62021512a").first
          blob_for_which_commit_not_found = commit.blobs.with_sha("b80d7482dba100beb55e65e82c5edb28589fa045").first

          expected_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                             ["Git::BlobNotFoundError", "Blob not found in git repo: 88e5b52732c23a4e33471d91cf2281e62021512a (failed in BlobImporter for commit_id #{commit.id} and blob_id #{blob_not_found.id})"],
                             ["Git::CommitNotFoundError", "Commit not found in git repo: fake_sha (failed in CommitKeyCreator for commit_id #{commit.id} and blob_id #{blob_for_which_commit_not_found.id})"],
                             ["Psych::SyntaxError", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1 (in /config/locales/ruby/broken.yml)"],
                             ["V8::Error", "Unexpected identifier at <eval>:2:12 (in /ember-broken/en-US.js)"]]

          expect(commit.reload.import_errors.sort).to eql(expected_errors.sort)
          expect_to_send_import_errors_email(expected_errors)
        end

        it "records the import error in CommitImporter due to a Git:CommitNotFoundError and sends an email after the import" do
          allow_any_instance_of(Commit).to receive(:commit!).and_raise(Git::CommitNotFoundError, "e5f5704af3c1f84cf42c4db46dcfebe8ab842bde") # fake a Git::CommitNotFoundError in CommitImporter

          ActionMailer::Base.deliveries.clear
          commit  = @project.commit!('e5f5704af3c1f84cf42c4db46dcfebe8ab842bde')

          expected_errors = [["Git::CommitNotFoundError", "Commit not found in git repo: e5f5704af3c1f84cf42c4db46dcfebe8ab842bde (failed in CommitImporter for commit_id #{commit.id})"]]
          expect(commit.reload.import_errors.sort).to eql(expected_errors.sort)
          expect_to_send_import_errors_email(expected_errors)
        end
      end
    end
  end
end

describe CommitImporter::Finisher do
  describe "#on_success" do
    before :each do
      @project = FactoryGirl.create(:project, :light)
      @commit = FactoryGirl.create(:commit, project: @project, loading: true)
      @key = FactoryGirl.create(:key, project: @project)
      @commit.keys << @key
      @translation = FactoryGirl.create(:translation, key: @key, copy: "test")
    end

    it "sets loading to false and sets ready to true if all translations are finished" do
      @key.update! ready: false
      @commit.update! ready: false
      @translation.update! source_copy: "test", approved: true
      expect(@commit.reload).to be_loading
      expect(@commit).to_not be_ready
      CommitImporter::Finisher.new.on_success true, 'commit_id' => @commit.id
      expect(@commit.reload).to_not be_loading
      expect(@commit).to be_ready
    end

    it "sets loading to false and sets ready to false if some translations are not translated" do
      @key.update! ready: false
      @commit.update! ready: false
      expect(@commit.reload).to be_loading
      expect(@commit).to_not be_ready
      CommitImporter::Finisher.new.on_success true, 'commit_id' => @commit.id
      expect(@commit.reload).to_not be_loading
      expect(@commit).to_not be_ready
    end

    it "recalculates keys' readiness, sets to false if not all translations are approved" do
      @key.update! ready: true
      CommitImporter::Finisher.new.on_success true, 'commit_id' => @commit.id
      expect(@key.reload).to_not be_ready
    end

    it "recalculates keys' readiness, sets to true if all translations are approved" do
      @translation.update! source_copy: "test", approved: true
      @key.update! ready: false
      CommitImporter::Finisher.new.on_success true, 'commit_id' => @commit.id
      expect(@key.reload).to be_ready
    end
  end
end
