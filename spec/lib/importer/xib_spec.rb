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

describe Importer::Xib do
  include ImporterTesting

  context "[importing]" do
    before(:each) do
      @project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Xib.new(@blob, 'some/path')
    end

    it "should import strings from SVG files" do
      test_importer @importer, File.read(Rails.root.join('spec', 'fixtures', 'example.xib')), 'Resources/en-US.lproj/test.xib'

      @project.keys.count.should eql(10)
      trans = @project.keys.for_key('Resources/en-US.lproj/test.xib:3.IBUIText').first.translations.find_by_rfc5646_locale('en-US')
      trans.copy.should eql('text field text')
      trans.key.context.should start_with('text field notes')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:8.IBUISelectedTitle').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('selected title')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:3.IBUIPlaceholder').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('placeholder text')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:8.IBUINormalTitle').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('button title')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:8.IBUIHighlightedTitle').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('highlighted title')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:8.IBUIDisabledTitle').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('disabled title')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:3.IBUIAccessibilityConfiguration.IBUIAccessibilityLabel').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('accessibility label')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:3.IBUIAccessibilityConfiguration.IBUIAccessibilityHint').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('accessibility hint')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:12.IBSegmentTitles[0]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('segment 1')
      @project.keys.for_key('Resources/en-US.lproj/test.xib:12.IBSegmentTitles[1]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('segment 2')
    end
  end
end

