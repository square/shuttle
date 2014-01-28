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
  describe "#import_strings" do
    before :all do
      @project = FactoryGirl.create(:project)
      @blob    = FactoryGirl.create(:blob, project: @project)
    end

    it "should call #import on an importer subclass" do
      imp = Importer::Base.implementations
      instance = double(imp.to_s, :skip? => false)
      expect(imp).to receive(:new).once.with(@blob, 'some/path', nil).and_return(instance)
      expect(instance).to receive(:import).once
      @blob.import_strings imp, 'some/path'
    end

    it "should pass a commit if given using :commit" do
      commit = FactoryGirl.create(:commit, project: @project)
      imp = Importer::Base.implementations.first
      instance = double(imp.to_s, :skip? => false)
      expect(imp).to receive(:new).once.with(@blob, 'some/path', commit).and_return(instance)
      expect(instance).to receive(:import).once
      @blob.import_strings imp, 'some/path', commit: commit
    end
  end
end
