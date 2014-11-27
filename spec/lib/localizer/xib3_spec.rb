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

describe Localizer::Xib3 do
  before :each do
    @project = FactoryGirl.create(:project,
                                  repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                  only_paths:     %w(apple/),
                                  skip_imports:   Importer::Base.implementations.map(&:ident) - %w(xib3))
    @commit  = @project.commit!('HEAD')

    {
        '/apple/en-US.lproj/example3.xib:3.text'                                            => 'text field text',
        '/apple/en-US.lproj/example3.xib:8.state[selected].title'                           => 'selected title',
        '/apple/en-US.lproj/example3.xib:3.placeholder'                                     => 'placeholder text',
        '/apple/en-US.lproj/example3.xib:8.state[normal].title'                             => 'button title',
        '/apple/en-US.lproj/example3.xib:8.state[highlighted].title'                        => 'highlighted title',
        '/apple/en-US.lproj/example3.xib:8.state[disabled].title'                           => 'disabled title',
        '/apple/en-US.lproj/example3.xib:3.accessibility[accessibilityConfiguration].label' => 'accessibility label',
        '/apple/en-US.lproj/example3.xib:3.accessibility[accessibilityConfiguration].hint'  => 'accessibility hint',
        '/apple/en-US.lproj/example3.xib:12.segments.segment[0].title'                      => 'segment 1',
        '/apple/en-US.lproj/example3.xib:12.segments.segment[1].title'                      => 'segment 2'
    }.each do |key, string|
      key = @project.keys.for_key(key).source_copy_matches(string).first!
      key.translations.where(rfc5646_locale: 'de-DE').first!.update_attributes(
          copy:     "#{string} (de)",
          approved: true)
      key.recalculate_ready!
    end
  end

  it "should localize a Xib file" do
    compiler = Compiler.new(@commit.reload)
    file     = compiler.localize

    entries = Hash.new
    Archive.read_open_memory(file.io.read, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
      while (entry = archive.next_header)
        expect(entry).to be_regular
        entries[entry.pathname] = archive.read_data.force_encoding('UTF-8')
      end
    end

    #entries.size.should >= 2
    #entries['apple/de-DE.lproj/example3.xib'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'example3-de.xib')))
    #entries['apple/de-DE.lproj/no-translations3.xib'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'no-translations3.xib')))
    #TODO re-enable when enabling CopiesIosResourcesWithoutTranslations

    expect(entries.size).to eq(1)
    expect(entries['apple/de-DE.lproj/example3.xib']).to eql(File.read(Rails.root.join('spec', 'fixtures', 'example3-de.xib')))
  end
end
