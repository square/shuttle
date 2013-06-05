# encoding: utf-8

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

# encoding: utf-8

require 'spec_helper'

describe Localizer::Xib do
  before :all do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')
    @commit  = FactoryGirl.create(:commit, project: @project)

    {
        'Resources/en-US.lproj/test.xib:3.IBUIText'                                              => 'text field text',
        'Resources/en-US.lproj/test.xib:8.IBUISelectedTitle'                                     => 'selected title',
        'Resources/en-US.lproj/test.xib:3.IBUIPlaceholder'                                       => 'placeholder text',
        'Resources/en-US.lproj/test.xib:8.IBUINormalTitle'                                       => 'button title',
        'Resources/en-US.lproj/test.xib:8.IBUIHighlightedTitle'                                  => 'highlighted title',
        'Resources/en-US.lproj/test.xib:8.IBUIDisabledTitle'                                     => 'disabled title',
        'Resources/en-US.lproj/test.xib:3.IBUIAccessibilityConfiguration.IBUIAccessibilityLabel' => 'accessibility label',
        'Resources/en-US.lproj/test.xib:3.IBUIAccessibilityConfiguration.IBUIAccessibilityHint'  => 'accessibility hint',
        'Resources/en-US.lproj/test.xib:12.IBSegmentTitles[0]'                                   => 'segment 1',
        'Resources/en-US.lproj/test.xib:12.IBSegmentTitles[1]'                                   => 'segment 2'
    }.each do |key, string|
      key = FactoryGirl.create(:key,
                               project:      @project,
                               key:          "/Resources/en-US.lproj/example.xib:#{key}",
                               original_key: key,
                               source:       '/Resources/en-US.lproj/example.xib')
      FactoryGirl.create :translation,
                         key:           key,
                         source_locale: @en,
                         locale:        @de,
                         source_copy:   string,
                         copy:          "#{string} (de)"
      @commit.keys << key
    end
  end

  it "should localize a Xib file" do
    input_file  = Localizer::File.new("Resources/en-US.lproj/example.xib", File.read(Rails.root.join('spec', 'fixtures', 'example.xib')))
    output_file = Localizer::File.new

    Localizer::Xib.new(@project, @commit.translations).localize input_file, output_file, @de

    output_file.path.should eql('Resources/de-DE.lproj/example.xib')
    output_file.content.should eql(File.read(Rails.root.join('spec', 'fixtures', 'example-de.xib')))
  end
end
