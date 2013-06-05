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

describe Importer::Erb do
  include ImporterTesting

  context "[importing]" do
    before(:each) do
      @project = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Erb.new(@blob, 'some/path')
    end

    it "should import one big string from an ERb file" do
      file = <<-ERB
some text here <%= something %>.
      ERB
      test_importer @importer, file, 'foo/bar.text.erb'

      @project.keys.count.should eql(1)
      @project.keys.for_key('foo/bar.text.erb').first.translations.find_by_rfc5646_locale('en-US').copy.should eql(file)
    end

    it "should fence HTML tags in HTML ERB files" do
      file = <<-ERB
some <b>text</b> here <%= something %>.
      ERB
      test_importer @importer, file, 'foo/bar.html.erb'

      @project.keys.count.should eql(1)
      translation = @project.keys.for_key('foo/bar.html.erb').first.translations.find_by_rfc5646_locale('en-US')
      translation.copy.should eql(file)
      translation.fences.should eql(
                                    '<%= something %>' => [22..37],
                                    '<b>'              => [5..7],
                                    '</b>'             => [12..15]
                                )
    end
  end
end
