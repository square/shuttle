# encoding: utf-8

# Copyright 2017 Square Inc.
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

describe Localizer::Mustache do
  before :each do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')
    @commit  = FactoryGirl.create(:commit, project: @project)

    key = FactoryGirl.create(:key,
                             project: @project,
                             key:     '/mustache/example.en-US.mustache',
                             source:  '/mustache/example.en-US.mustache')
    FactoryGirl.create :translation,
                       key:           key,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "hello {{world}}",
                       copy:          "hallo {{world}}"

    @commit.keys = [key]
  end

  it "should localize a Mustache file" do
    input_file = Localizer::File.new('mustache/example.en-US.mustache', <<-TXT.chomp)
hello {{world}}
    TXT
    output_file = Localizer::File.new

    Localizer::Mustache.new(@project, @commit.translations).localize input_file, output_file, @de

    expect(output_file.path).to eql('mustache/example.de-DE.mustache')
    expect(output_file.content).to eql(<<-TXT.chomp)
hallo {{world}}
    TXT
  end
end
