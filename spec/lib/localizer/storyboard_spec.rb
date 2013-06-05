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

describe Localizer::Storyboard do
  before :all do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')
    @commit  = FactoryGirl.create(:commit, project: @project)

    {
        'Uku-Po-7eL.text'                                            => 'text field text',
        'Uku-Po-7eL.placeholder'                                     => 'text field placeholder',
        'TfH-0c-wqN.headerTitle'                                     => 'table section header',
        'TfH-0c-wqN.footerTitle'                                     => 'table section footer',
        'XtV-Di-hKk.title'                                           => 'nav bar title 1',
        'kDj-4K-brs.title'                                           => 'nav bar title 2',
        'f3V-y0-8XT.state[selected].title'                           => 'selected title',
        'f3V-y0-8XT.state[normal].title'                             => 'button title',
        'f3V-y0-8XT.state[highlighted].title'                        => 'highlighted title',
        'f3V-y0-8XT.state[disabled].title'                           => 'disabled title',
        'wQO-PX-mfF.segments.segment[1].title'                       => 'segment 2',
        'wQO-PX-mfF.segments.segment[0].title'                       => 'segment 1',
        'Uku-Po-7eL.accessibility[accessibilityConfiguration].label' => 'accessibility label',
        'Uku-Po-7eL.accessibility[accessibilityConfiguration].hint'  => 'accessibility hint',
        'beo-Nd-8Qm.title'                                           => 'view controller title',
        'NN0-LQ-6Cj.text'                                            => "has\nnewline"
    }.each do |key, string|
      key = FactoryGirl.create(:key,
                               project:      @project,
                               key:          "/Resources/en-US.lproj/example.storyboard:#{key}",
                               original_key: key,
                               source:       '/Resources/en-US.lproj/example.storyboard')
      @commit.keys << key
      FactoryGirl.create :translation,
                         key:           key,
                         source_locale: @en,
                         locale:        @de,
                         source_copy:   string,
                         copy:          "#{string} (de)"
    end
  end

  it "should localize a Storyboard file" do
    input_file  = Localizer::File.new("Resources/en-US.lproj/example.storyboard", File.read(Rails.root.join('spec', 'fixtures', 'example.storyboard')))
    output_file = Localizer::File.new

    Localizer::Storyboard.new(@project, @commit.translations).localize input_file, output_file, @de

    output_file.path.should eql('Resources/de-DE.lproj/example.storyboard')
    output_file.content.should eql(File.read(Rails.root.join('spec', 'fixtures', 'example-de.storyboard')))
  end
end
