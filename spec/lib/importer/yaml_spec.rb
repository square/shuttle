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

# encoding: UTF-8
require 'spec_helper'

describe Importer::Yaml do
  include ImporterTesting

  context "[importing]" do
    before(:each) do
      @project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Yaml.new(@blob, 'some/path')
    end

    it "should import strings from YAML files" do
      test_importer @importer, <<-YAML
en-US:
  root: root
  nested:
    one: one
    "2": two
      YAML

      @project.keys.count.should eql(3)
      @project.keys.for_key('root').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('root')
      @project.keys.for_key('nested.one').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('one')
      @project.keys.for_key('nested.2').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('two')
    end

    it "should only import strings under the correct localization" do
      test_importer @importer, <<-YAML
en-US:
  root: root
en:
  root: enroot
      YAML

      @project.keys.count.should eql(1)
      @project.keys.for_key('root').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('root')
    end

    it "should not fail if the correct localization is not in the file" do
      test_importer @importer, <<-YAML
jp:
  root: root
      YAML

      @project.keys.count.should eql(0)
    end

    it "should import string arrays" do
      test_importer @importer, <<-YAML
en-US:
  date:
    abbr_month_names:
    -
    - Jan
    - Feb
    - Mar
    - Apr
    - May
    - Jun
    - Jul
    - Aug
    - Sep
    - Oct
    - Nov
    - Dec
  helicopter:
    rofl
      YAML

      @project.keys.count.should eql(13)
      @project.keys.for_key('date.abbr_month_names[2]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Feb')
      @project.keys.for_key('date.abbr_month_names[12]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Dec')
    end
  end
end
