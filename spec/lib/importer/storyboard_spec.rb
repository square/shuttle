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

describe Importer::Storyboard do
  context "[importing]" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(apple/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(storyboard))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from SVG files" do
      trans = @project.keys.for_key('/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.text').first.translations.find_by_rfc5646_locale('en-US')
      trans.copy.should eql('text field text')
      trans.key.context.should start_with('text field notes')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.placeholder').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('text field placeholder')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:TfH-0c-wqN.headerTitle').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('table section header')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:TfH-0c-wqN.footerTitle').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('table section footer')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:XtV-Di-hKk.title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('nav bar title 1')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:kDj-4K-brs.title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('nav bar title 2')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[selected].title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('selected title')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[normal].title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('button title')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[highlighted].title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('highlighted title')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[disabled].title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('disabled title')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:wQO-PX-mfF.segments.segment[1].title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('segment 2')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:wQO-PX-mfF.segments.segment[0].title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('segment 1')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.accessibility[accessibilityConfiguration].label').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('accessibility label')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.accessibility[accessibilityConfiguration].hint').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('accessibility hint')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:beo-Nd-8Qm.title').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('view controller title')
      @project.keys.for_key('/apple/en-US.lproj/example.storyboard:NN0-LQ-6Cj.text').first.translations.find_by_rfc5646_locale('en-US').copy.should eql("has\nnewline")
    end
  end
end

