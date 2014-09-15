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

describe Importer::Strings do
  context "[importing]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(apple/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(strings))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from .strings files" do
      expect(@project.keys.for_key('/apple/en-US.lproj/example.strings:dialogue.marta.1').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('Te Quiero.')
      expect(@project.keys.for_key('/apple/en-US.lproj/example.strings:dialogue.gob.1').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('English, please.')
      expect(@project.keys.for_key('/apple/en-US.lproj/example.strings:dialogue.marta.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql('I love you.')
      expect(@project.keys.for_key('/apple/en-US.lproj/example.strings:dialogue.gob.2').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("Great. Now I'm late for work.")
    end

    it "should properly unescape C string escapes" do
      expect(@project.keys.for_key("/apple/en-US.lproj/example.strings:Something\nwith\tescapes\\").first.translations.base.first.copy).to eql("Something\nwith\tescapes\\")
    end

    it "should still import strings that end with <DNL>" do
      expect(@project.keys.for_key('/apple/en-US.lproj/example.strings:quote.charlie.1').first.translations.find_by_rfc5646_locale('en-US').copy).to eql("I'm a patriot. You've gotta give me that.<DNL>")
    end

    it "should not import strings that start with <DNL>" do
      expect(@project.keys.for_key('/apple/en-US.lproj/no-translations.strings:dialogue.charlie.1').first).to be_nil
      expect(@project.keys.for_key('/apple/en-US.lproj/no-translations.strings:dialogue.dennis.1').first).to be_nil
      expect(@project.keys.for_key('/apple/en-US.lproj/no-translations.strings:dialogue.charlie.2').first).to be_nil
      expect(@project.keys.for_key('/apple/en-US.lproj/no-translations.strings:dialogue.dennis.2').first).to be_nil
    end
  end
end
