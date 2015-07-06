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

describe Importer::Xib3 do
  context "[importing]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(apple/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(xib3))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from Xcode 5 xib files" do
      trans = @project.keys.for_key('/apple/en-US.lproj/example3.xib:3.text').first.translations.find_by_rfc5646_locale('en-US')
      expect(trans.copy).to eql('text field text')
      expect(trans.key.context).to start_with('text field notes')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:8.state[selected].title').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('selected title')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:3.placeholder').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('placeholder text')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:8.state[normal].title').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('button title')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:8.state[highlighted].title').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('highlighted title')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:8.state[disabled].title').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('disabled title')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:3.accessibility[accessibilityConfiguration].label').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('accessibility label')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:3.accessibility[accessibilityConfiguration].hint').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('accessibility hint')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:12.segments.segment[0].title').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('segment 1')
      expect(@project.keys.for_key('/apple/en-US.lproj/example3.xib:12.segments.segment[1].title').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('segment 2')
    end
  end
end
