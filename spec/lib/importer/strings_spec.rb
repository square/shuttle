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

describe Importer::Strings do
  include ImporterTesting

  context "[importing]" do
    before(:each) do
      @project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Strings.new(@blob, 'some/path')
    end

    it "should import strings from .strings files" do
      test_importer @importer, <<-C, 'Resources/en.lproj/stuff.strings'
/* Marta is trying to be sincere and sweet. */
"dialogue.marta.1" = "Te Quiero.";

/* GOB is being insensitive to her culture. */
"dialogue.gob.1" = "English, please.";

/* Marta capitulates and repeats in English. */
"dialogue.marta.2" = "I love you.";

/* GOB is frustrated that the conversation is still going. */
"dialogue.gob.2" = "Great. Now I'm late for work.";
      C

      @project.keys.count.should eql(4)
      @project.keys.for_key('Resources/en.lproj/stuff.strings:dialogue.marta.1').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Te Quiero.')
      @project.keys.for_key('Resources/en.lproj/stuff.strings:dialogue.gob.1').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('English, please.')
      @project.keys.for_key('Resources/en.lproj/stuff.strings:dialogue.marta.2').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('I love you.')
      @project.keys.for_key('Resources/en.lproj/stuff.strings:dialogue.gob.2').first.translations.find_by_rfc5646_locale('en-US').copy.should eql("Great. Now I'm late for work.")
    end

    it "should properly unescape C string escapes" do
      test_importer @importer, <<-C, 'Resources/en.lproj/stuff.strings'
"Something\\nwith\\t\\145scapes\\\\" = "Something\\nwith\\t\\145scapes\\\\";
      C

      @project.keys.count.should eql(1)
      @project.keys.for_key("Resources/en.lproj/stuff.strings:Something\nwith\tescapes\\").first.translations.base.first.copy.should eql("Something\nwith\tescapes\\")
    end
  end
end
