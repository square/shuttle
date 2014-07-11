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

describe Git::NotFoundError do
  describe "#initialize" do
    it "creates a Git::NotFoundError which is a kind of StandardError that has a message derived from the given sha and object_type" do
      err = Git::NotFoundError.new('xyz123', 'MyType')
      expect(err).to be_a_kind_of(StandardError)
      expect(err.message).to eql("MyType not found in git repo: xyz123")
    end
  end
end

describe Git::CommitNotFoundError do
  describe "#initialize" do
    it "creates a Git::CommitNotFoundError which is a kind of Git::NotFoundError that has a message derived from the given sha" do
      err = Git::CommitNotFoundError.new('xyz123')
      expect(err).to be_a_kind_of(Git::NotFoundError)
      expect(err.message).to eql("Commit not found in git repo: xyz123")
    end
  end
end

describe Git::BlobNotFoundError do
  describe "#initialize" do
    it "creates a Git::BlobNotFoundError which is a kind of Git::NotFoundError that has a message derived from the given sha" do
      err = Git::BlobNotFoundError.new('xyz123')
      expect(err).to be_a_kind_of(Git::NotFoundError)
      expect(err.message).to eql("Blob not found in git repo: xyz123")
    end
  end
end
