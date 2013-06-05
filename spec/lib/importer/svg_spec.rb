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

describe Importer::Svg do
  include ImporterTesting

  context "[importing]" do
    before(:each) do
      @project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Svg.new(@blob, 'some/path')
    end

    it "should import strings from SVG files" do
      test_importer @importer, <<-XML, 'file-en-US.svg'
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

      @project.keys.count.should eql(2)
      @project.keys.for_key('file-en-US.svg:/*/*[1]').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Hello, world!')
      @project.keys.for_key('file-en-US.svg:/*/*[2]/*').first.translations.find_by_rfc5646_locale('en-US').copy.should eql('Grouped text')
    end
  end
end

