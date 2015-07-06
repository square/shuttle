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

describe Blob do
  before :each do
    @project = FactoryGirl.create(:project)
    @repo = double('Git::Repo')
    @blob = FactoryGirl.create(:blob, sha: 'abc123', project: @project)
    @commit = FactoryGirl.create(:commit, project: @project)
  end

  describe "#import_strings" do
    it "should call #import on an importer subclass" do
      expect(@blob).to receive(:blob!).and_return(double(Git::Object::Blob))
      imp      = Importer::Base.implementations
      instance = double(imp.to_s, :skip? => false)
      expect(imp).to receive(:new).once.with(@blob, @commit).and_return(instance)
      expect(instance).to receive(:import).once
      @blob.import_strings imp, @commit
    end

    it "should pass a commit if given using :commit" do
      expect(@blob).to receive(:blob!).and_return(double(Git::Object::Blob))
      imp      = Importer::Base.implementations.first
      instance = double(imp.to_s, :skip? => false)
      expect(imp).to receive(:new).once.with(@blob, @commit).and_return(instance)
      expect(instance).to receive(:import).once
      @blob.import_strings imp, @commit
    end

    it "should raise an exception if sha is still unknown after fetching" do
      allow(@project).to receive(:repo).and_yield(@repo)
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil)
      expect { @blob.import_strings(double(Importer::Yaml), @commit) }.to raise_error(Git::BlobNotFoundError)
    end
  end

  describe "#blob" do
    it "raises Project::NotLinkedToAGitRepositoryError if repository_url is nil" do
      project = FactoryGirl.create(:project, repository_url: nil)
      blob = FactoryGirl.create(:blob, project: project)
      expect { blob.blob }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end

    it "returns the git blob object" do
      @blob_obj = double('Git::Object::Blob', sha: 'abc123')
      expect(File).to receive(:exist?).and_return(true)
      expect(Git).to receive(:bare).and_return(@repo)
      expect(@repo).to receive(:object).with("abc123").and_return(@blob_obj)
      expect(@blob.blob).to eql(@blob_obj)
    end
  end

  describe "#blob!" do
    before :each do
      allow(@project).to receive(:repo).and_yield(@repo)
      @blob_obj = double('Git::Object::Blob', sha: 'abc123')
    end

    it "returns the git object for the blob without fetching if it's already in local repo" do
      expect(@repo).to_not receive(:fetch)
      expect(@repo).to receive(:object).with('abc123').once.and_return(@blob_obj)
      expect(@blob.blob!).to eql(@blob_obj)
    end

    it "returns the git object for the blob after fetching if it's not initially in local repo, but is in the remote repo" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil, @blob_obj)
      expect(@blob.blob!).to eql(@blob_obj)
    end

    it "raises Git::BlobNotFoundError if the sha is not found" do
      expect(@repo).to receive(:fetch).once
      expect(@repo).to receive(:object).with('abc123').twice.and_return(nil)
      expect { @blob.blob! }.to raise_error(Git::BlobNotFoundError, "Blob not found in git repo: abc123")
    end

    it "raises Project::NotLinkedToAGitRepositoryError if repository_url is nil" do
      project = FactoryGirl.create(:project, repository_url: nil)
      blob = FactoryGirl.create(:blob, project: project)
      expect { blob.blob }.to raise_error(Project::NotLinkedToAGitRepositoryError)
    end
  end
end
