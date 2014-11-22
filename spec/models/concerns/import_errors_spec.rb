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

describe ImportErrors do
  before(:each) do
    @commit = FactoryGirl.create(:commit)
  end

  context "set_nil_if_blank" do
    it "import_errors should be set to nil if it's blank so that it can be easily queryable" do
      @commit.update! import_errors: []
      expect(Commit.where(import_errors: nil).to_a).to eql([@commit])
    end
  end

  describe "#errored_during_import" do
    it "returns the imports which errored during an import" do
      FactoryGirl.create(:commit, import_errors: [])
      @commit.add_import_error(StandardError.new("This is a fake error"))
      expect(Commit.errored_during_import.to_a).to eql([@commit])
    end
  end

  describe "#add_import_error" do
    it "should add an import error to commit with the default message" do
      @commit.add_import_error(StandardError.new("This is a fake error"))
      expect(@commit.import_errors).to eql([["StandardError", "This is a fake error"]])
    end

    it "should add an import error to commit with a custom message" do
      @commit.add_import_error(StandardError.new("This is a fake error"), "in /path/to/some/file")
      expect(@commit.import_errors).to eql([["StandardError", "This is a fake error (in /path/to/some/file)"]])
    end
  end

  describe "#clear_import_errors!" do
    it "should clear all import errors of a commit in redis and postgres" do
      @commit.add_import_error(StandardError.new("first fake error"))
      @commit.add_import_error(StandardError.new("second fake error"), "in /path/to/some/file")
      expect(@commit.import_errors.sort).to eql([["StandardError", "first fake error"], ["StandardError", "second fake error (in /path/to/some/file)"]].sort)

      @commit.clear_import_errors!
      expect(@commit.import_errors).to eql([])
    end
  end

  describe "#errored_during_import?" do
    it "returns true if there are import errors" do
      @commit.add_import_error(StandardError.new("This is a fake error"))
      expect(@commit.errored_during_import?).to be_true
    end

    it "returns false if there are no import errors" do
      @commit.clear_import_errors!
      expect(@commit.errored_during_import?).to be_false
    end
  end
end
