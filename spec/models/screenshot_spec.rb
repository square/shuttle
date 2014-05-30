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

describe Screenshot do
  it { should have_attached_file(:image) }
  it { should validate_attachment_presence(:image) }
  it { should validate_attachment_content_type(:image).allowing(Screenshot::CONTENT_TYPES) }
  it { should validate_attachment_size(:image).less_than(5.megabytes) }

  it 'creates a thumbs style' do
    expect(Screenshot.attachment_definitions[:image][:styles][:thumb]).to_not be_nil
  end

  it 'creates a dimensions for thumbs style' do
    expect(Screenshot.attachment_definitions[:image][:styles][:thumb]).to eql('400x200')
  end
end
