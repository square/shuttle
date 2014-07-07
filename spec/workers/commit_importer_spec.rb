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
        it "adds import errors to commit in redis when commit importer fails due to a Git::CommitNotFoundError" do
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_return(nil)
          project = FactoryGirl.create(:project)
          commit = FactoryGirl.create(:commit, revision: "abc123", project: project)

          expect { CommitImporter.new.perform(commit.id) }.to_not raise_error
          expect(commit.import_errors_in_redis).to eql([["Git::CommitNotFoundError", "Commit not found in git repo: abc123 (it may have been rebased away) (failed in CommitImporter for commit_id #{commit.id})"]])
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

        before :all do
          Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s).delete_all
        end

        before :each do
          @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)
        end

        it "records all import errors and sends an email after the import if errors occured during the import" do
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_call_original
          allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).with("88e5b52732c23a4e33471d91cf2281e62021512a").and_return(nil) # fake a Git::BlobNotFoundError in CommitImporter
          allow_any_instance_of(Commit).to receive(:skip_key?).with("how_are_you").and_raise(Git::CommitNotFoundError, "fake_sha") # fake a CommitNotFoundError error in KeyCreator failure

          ActionMailer::Base.deliveries.clear
          commit  = @project.commit!('e5f5704af3c1f84cf42c4db46dcfebe8ab842bde')

          expected_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                             ["Git::BlobNotFoundError", "Blob not found in git repo: 88e5b52732c23a4e33471d91cf2281e62021512a (it may have been rebased away) (failed in BlobImporter for commit_id #{commit.id} and blob 88e5b52732c23a4e33471d91cf2281e62021512a)"],
                             ["Git::CommitNotFoundError", "Commit not found in git repo: fake_sha (it may have been rebased away) (failed in KeyCreator for commit_id #{commit.id} and blob b80d7482dba100beb55e65e82c5edb28589fa045)"],
                             ["Psych::SyntaxError", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1 (in /config/locales/ruby/broken.yml)"],
                             ["V8::Error", "Unexpected identifier at <eval>:2:12 (in /ember-broken/en-US.js)"]]

          expect(commit.reload.import_errors.sort).to eql(expected_errors.sort)
          expect_to_send_import_errors_email(expected_errors)
        end

        it "records the import error in CommitImporter due to a Git:CommitNotFoundError and sends an email after the import" do
          allow_any_instance_of(Commit).to receive(:import_strings).and_raise(Git::CommitNotFoundError, "e5f5704af3c1f84cf42c4db46dcfebe8ab842bde") # fake a Git::CommitNotFoundError in CommitImporter

          ActionMailer::Base.deliveries.clear
          commit  = @project.commit!('e5f5704af3c1f84cf42c4db46dcfebe8ab842bde')

          expected_errors = [["Git::CommitNotFoundError", "Commit not found in git repo: e5f5704af3c1f84cf42c4db46dcfebe8ab842bde (it may have been rebased away) (failed in CommitImporter for commit_id #{commit.id})"]]
          expect(commit.reload.import_errors.sort).to eql(expected_errors.sort)
          expect_to_send_import_errors_email(expected_errors)
        end
      end
    end
  end
end
