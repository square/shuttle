# encoding: utf-8

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

describe Localizer::Svg do
  before :each do
    @project = FactoryGirl.create(:project)
    @en      = Locale.from_rfc5646('en-US')
    @de      = Locale.from_rfc5646('de-DE')
    @commit  = FactoryGirl.create(:commit, project: @project)

    key1 = FactoryGirl.create(:key,
                              project:      @project,
                              key:          'file-en-US.svg:/*/*[1]',
                              original_key: '/*/*[1]',
                              source:       'file-en-US.svg')
    FactoryGirl.create :translation,
                       key:           key1,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Hello, world!",
                       copy:          "Hallo, Welt!"

    key2 = FactoryGirl.create(:key,
                              project:      @project,
                              key:          'file-en-US.svg:/*/*[2]/*',
                              original_key: '/*/*[2]/*',
                              source:       'file-en-US.svg')
    FactoryGirl.create :translation,
                       key:           key2,
                       source_locale: @en,
                       locale:        @de,
                       source_copy:   "Grouped text",
                       copy:          "Gruppierten text"

    @commit.keys = [key1, key2]
  end

  it "should localize an SVG file" do
    input_file = Localizer::File.new("file-en-US.svg", <<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
    "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" width="292px"
	 height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hello, world!</text>
  <g>
    <text>Grouped text</text>
  </g>
</svg>
    XML
    output_file = Localizer::File.new

    Localizer::Svg.new(@project, @commit.translations).localize input_file, output_file, @de

    expect(output_file.path).to eql('file-de-DE.svg')
    expect(output_file.content).to eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hallo, Welt!</text>
  <g>
    <text>Gruppierten text</text>
  </g>
</svg>
    XML
  end
end
