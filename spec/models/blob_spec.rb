# Copyright 2013 Square Inc.
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

    it "should call #import on all importer subclasses" do
      Importer::Base.implementations.each do |imp|
        instance = mock(imp.to_s, :skip? => false)
        imp.should_receive(:new).once.with(@blob, 'some/path', nil).and_return(instance)
        instance.should_receive(:import).once
      end
      @blob.import_strings 'some/path'
    end

    it "should not call #import on any disabled importer subclasses" do
      @project.update_attribute :skip_imports, %w(Importer::Ruby Importer::Yaml)
      Importer::Base.implementations.each do |imp|
        if imp == Importer::Ruby || imp == Importer::Yaml
          imp.should_not_receive(:new)
        else
          instance = mock(imp.to_s, :skip? => false)
          imp.should_receive(:new).once.with(@blob, 'some/path', nil).and_return(instance)
          instance.should_receive(:import).once
        end
      end
      @blob.import_strings 'some/path'
      @project.update_attribute :skip_imports, []
    end

    it "should call import_locale if :locale is given" do
      locale = Locale.from_rfc5646('de')
      Importer::Base.implementations.each do |imp|
        instance = mock(imp.to_s, :skip? => false)
        imp.should_receive(:new).once.with(@blob, 'some/path', nil).and_return(instance)
        instance.should_receive(:import_locale).once.with(locale)
      end
      @blob.import_strings 'some/path', locale: locale
    end

    it "should pass a commit if given using :commit" do
      commit = FactoryGirl.create(:commit, project: @project)
      Importer::Base.implementations.each do |imp|
        instance = mock(imp.to_s, :skip? => false)
        imp.should_receive(:new).once.with(@blob, 'some/path', commit).and_return(instance)
        instance.should_receive(:import).once
      end
      @blob.import_strings 'some/path', commit: commit
    end

    it "should skip any importers for which #skip? returns true" do
      Importer::Base.implementations.each do |imp|
        instance = mock(imp.to_s)
        imp.should_receive(:new).once.with(@blob, 'some/path', nil).and_return(instance)
        instance.should_receive(:skip?).once.with(nil).and_return(true)
        instance.should_not_receive(:import)
      end
      @blob.import_strings 'some/path'
    end
  end
end
