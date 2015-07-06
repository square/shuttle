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

describe BlobImporter do
  describe "#perform" do
    context "[rescue Git::BlobNotFoundError]" do
      it "adds import errors to commit in redis when blob importer fails due to a Git::BlobNotFoundError" do
        allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_return(nil)
        @project = FactoryGirl.create(:project)
        @commit = FactoryGirl.create(:commit, project: @project)
        @blob = FactoryGirl.create(:blob, sha: "abc123", project: @project)
        @commit.blobs << @blob

        expect { BlobImporter.new.perform("yaml", @blob.id, @commit.id) }.to_not raise_error
        expect(@commit.reload.import_errors).to eql([["Git::BlobNotFoundError", "Blob not found in git repo: abc123 (failed in BlobImporter for commit_id #{@commit.id} and blob_id #{@blob.id})"]])
      end
    end
  end
end
