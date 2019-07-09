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

require 'rails_helper'

RSpec.describe CommitImporter do
  context "[unit-tests]" do
    describe "#perform" do
      context "[rescue Git::CommitNotFoundError]" do
        it "deletes the commit when commit importer fails due to a Git::CommitNotFoundError" do
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_return(nil)
          project = FactoryBot.create(:project)
          commit  = FactoryBot.create(:commit, revision: "abc123", project: project)
          CommitsIndex.reset!

          CommitImporter.new.perform commit.id
          expect { commit.reload }.to raise_error(ActiveRecord::RecordNotFound)
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
          expected_errors.each do |err_class, _err_message|
            expect(mail.body).to include(err_class)
          end
        end

        before :each do
          @project = FactoryBot.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)
        end

        it "records all import errors and sends an email after the import if errors occured during the import (such as in BlobImporter or CommitKeyCreator)" do
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_call_original
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).with("88e5b52732c23a4e33471d91cf2281e62021512a").and_return(nil) # fake a Git::BlobNotFoundError in CommitImporter
          allow_any_instance_of(Commit).to receive(:skip_key?).with("how_are_you").and_raise(Git::CommitNotFoundError, "fake_sha") # fake a CommitNotFoundError error in CommitKeyCreator failure

          ActionMailer::Base.deliveries.clear
          commit                          = @project.commit!('e5f5704af3c1f84cf42c4db46dcfebe8ab842bde')
          blob_not_found                  = commit.blobs.with_sha("88e5b52732c23a4e33471d91cf2281e62021512a").first
          blob_for_which_commit_not_found = commit.blobs.with_sha("b80d7482dba100beb55e65e82c5edb28589fa045").first

          expected_errors = %w[Psych::SyntaxError Git::BlobNotFoundError Git::CommitNotFoundError ExecJS::RuntimeError ExecJS::RuntimeError]

          CommitImporter::Finisher.new.on_success true, 'commit_id' => commit.id
          expect(commit.reload.import_errors.map(&:first)).to match_array(expected_errors)
          expect_to_send_import_errors_email(expected_errors)
        end
      end
    end
  end
end

RSpec.describe CommitImporter::Finisher do
  describe "#on_success" do
    before :each do
      @project = FactoryBot.create(:project, :light)
      @commit  = FactoryBot.create(:commit, project: @project, loading: true)
      @key     = FactoryBot.create(:key, project: @project)
      @commit.keys << @key
      @translation = FactoryBot.create(:translation, key: @key, copy: "test")
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

    it "sets the commit's fingerprint when fingerprint is not present" do
      CommitImporter::Finisher.new.on_success true, 'commit_id' => @commit.id

      expect(@commit.reload.fingerprint).to_not be_nil
      expected_fingerprint = Digest::SHA1.hexdigest(@key.id.to_s)
      expect(@commit.fingerprint).to eq expected_fingerprint
      expect(@commit.duplicate).to be false
    end

    it "does not change commit's fingerprint when fingerprint is present (duplicate is false)" do
      expected_fingerprint = Digest::SHA1.hexdigest(@key.id.to_s)
      @commit.fingerprint = expected_fingerprint
      @commit.duplicate = false
      @commit.save!

      # when duplicate is false
      expect(@commit.fingerprint).to eq expected_fingerprint
      expect(@commit.duplicate).to be false
    end

    it "does not change commit's fingerprint when fingerprint is present (duplicate is true)" do
      expected_fingerprint = Digest::SHA1.hexdigest(@key.id.to_s)
      @commit.fingerprint = expected_fingerprint
      @commit.duplicate = true
      @commit.save!

      CommitImporter::Finisher.new.on_success true, 'commit_id' => @commit.id
      expect(@commit.fingerprint).to eq expected_fingerprint
      expect(@commit.duplicate).to be true
    end

    it "sets following commits with same keys as duplicates" do
      expected_fingerprint = Digest::SHA1.hexdigest(@key.id.to_s)
      @commit.fingerprint = expected_fingerprint
      @commit.save!

      commit2 = FactoryBot.create(:commit, duplicate: false)
      commit2.keys << @key

      CommitImporter::Finisher.new.on_success true, 'commit_id' => commit2.id

      expect(@commit.reload.duplicate).to be false
      expect(commit2.reload.duplicate).to be true
    end

    it "sets following commits with different keys as not duplicates" do
      expected_fingerprint = Digest::SHA1.hexdigest(@key.id.to_s)
      @commit.fingerprint = expected_fingerprint
      @commit.save!

      commit2 = FactoryBot.create(:commit, duplicate: false)
      key2     = FactoryBot.create(:key, project: @project)
      commit2.keys << key2

      CommitImporter::Finisher.new.on_success true, 'commit_id' => commit2.id

      expect(@commit.reload.duplicate).to be false
      expect(commit2.reload.duplicate).to be false
    end
  end
end
