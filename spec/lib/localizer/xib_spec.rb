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

describe Localizer::Xib do
  before :each do
    @project = FactoryGirl.create(:project,
                                  repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                  only_paths:     %w(apple/),
                                  skip_imports:   Importer::Base.implementations.map(&:ident) - %w(xib))
    @commit  = @project.commit!('HEAD')

    {
        '/apple/en-US.lproj/example.xib:3.IBUIText'                                              => 'text field text',
        '/apple/en-US.lproj/example.xib:8.IBUISelectedTitle'                                     => 'selected title',
        '/apple/en-US.lproj/example.xib:3.IBUIPlaceholder'                                       => 'placeholder text',
        '/apple/en-US.lproj/example.xib:8.IBUINormalTitle'                                       => 'button title',
        '/apple/en-US.lproj/example.xib:8.IBUIHighlightedTitle'                                  => 'highlighted title',
        '/apple/en-US.lproj/example.xib:8.IBUIDisabledTitle'                                     => 'disabled title',
        '/apple/en-US.lproj/example.xib:3.IBUIAccessibilityConfiguration.IBUIAccessibilityLabel' => 'accessibility label',
        '/apple/en-US.lproj/example.xib:3.IBUIAccessibilityConfiguration.IBUIAccessibilityHint'  => 'accessibility hint',
        '/apple/en-US.lproj/example.xib:12.IBSegmentTitles[0]'                                   => 'segment 1',
        '/apple/en-US.lproj/example.xib:12.IBSegmentTitles[1]'                                   => 'segment 2'
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
    #entries['apple/de-DE.lproj/example.xib'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'example-de.xib')))
    #entries['apple/de-DE.lproj/no-translations.xib'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'no-translations.xib')))
    #TODO re-enable when enabling CopiesIosResourcesWithoutTranslations

    expect(entries.size).to eq(1)
    expect(entries['apple/de-DE.lproj/example.xib']).to eql(File.read(Rails.root.join('spec', 'fixtures', 'example-de.xib')))
  end
end
