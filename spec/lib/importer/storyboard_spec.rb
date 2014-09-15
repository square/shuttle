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

describe Importer::Storyboard do
  context "[importing]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(apple/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(storyboard))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from SVG files" do
      %w(example example3).each do |filename|
        trans = @project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:Uku-Po-7eL.text").first.translations.find_by_rfc5646_locale('en-US')
        expect(trans.copy).to eql('text field text')
        expect(trans.key.context).to start_with('text field notes')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:Uku-Po-7eL.placeholder").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('text field placeholder')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:TfH-0c-wqN.headerTitle").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('table section header')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:TfH-0c-wqN.footerTitle").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('table section footer')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:XtV-Di-hKk.title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('nav bar title 1')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:kDj-4K-brs.title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('nav bar title 2')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:f3V-y0-8XT.state[selected].title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('selected title')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:f3V-y0-8XT.state[normal].title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('button title')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:f3V-y0-8XT.state[highlighted].title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('highlighted title')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:f3V-y0-8XT.state[disabled].title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('disabled title')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:wQO-PX-mfF.segments.segment[1].title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('segment 2')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:wQO-PX-mfF.segments.segment[0].title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('segment 1')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:Uku-Po-7eL.accessibility[accessibilityConfiguration].label").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('accessibility label')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:Uku-Po-7eL.accessibility[accessibilityConfiguration].hint").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('accessibility hint')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:beo-Nd-8Qm.title").first.translations.find_by_rfc5646_locale('en-US').copy).to eql('view controller title')
        expect(@project.keys.for_key("/apple/en-US.lproj/#{filename}.storyboard:NN0-LQ-6Cj.text").first.translations.find_by_rfc5646_locale('en-US').copy).to eql("has\nnewline")
      end
    end
  end
end

