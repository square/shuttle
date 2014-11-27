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

describe Localizer::Storyboard do
  before :each do
    @project = FactoryGirl.create(:project,
                                  repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                  only_paths:     %w(apple/),
                                  skip_imports:   Importer::Base.implementations.map(&:ident) - %w(storyboard))
    @commit  = @project.commit!('HEAD')

    {
        '/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.text'                                            => 'text field text',
        '/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.placeholder'                                     => 'text field placeholder',
        '/apple/en-US.lproj/example.storyboard:TfH-0c-wqN.headerTitle'                                     => 'table section header',
        '/apple/en-US.lproj/example.storyboard:TfH-0c-wqN.footerTitle'                                     => 'table section footer',
        '/apple/en-US.lproj/example.storyboard:XtV-Di-hKk.title'                                           => 'nav bar title 1',
        '/apple/en-US.lproj/example.storyboard:kDj-4K-brs.title'                                           => 'nav bar title 2',
        '/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[selected].title'                           => 'selected title',
        '/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[normal].title'                             => 'button title',
        '/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[highlighted].title'                        => 'highlighted title',
        '/apple/en-US.lproj/example.storyboard:f3V-y0-8XT.state[disabled].title'                           => 'disabled title',
        '/apple/en-US.lproj/example.storyboard:wQO-PX-mfF.segments.segment[1].title'                       => 'segment 2',
        '/apple/en-US.lproj/example.storyboard:wQO-PX-mfF.segments.segment[0].title'                       => 'segment 1',
        '/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.accessibility[accessibilityConfiguration].label' => 'accessibility label',
        '/apple/en-US.lproj/example.storyboard:Uku-Po-7eL.accessibility[accessibilityConfiguration].hint'  => 'accessibility hint',
        '/apple/en-US.lproj/example.storyboard:beo-Nd-8Qm.title'                                           => 'view controller title',
        '/apple/en-US.lproj/example.storyboard:NN0-LQ-6Cj.text'                                            => "has\nnewline"
    }.each do |key, string|
      keyobj = @project.keys.for_key(key).source_copy_matches(string).first!
      keyobj.translations.where(rfc5646_locale: 'de-DE').first!.update_attributes(
          copy:     "#{string} (de)",
          approved: true)

      keyobj = @project.keys.for_key(key.sub('example.storyboard', 'example3.storyboard')).source_copy_matches(string).first!
      keyobj.translations.where(rfc5646_locale: 'de-DE').first!.update_attributes(
          copy:     "#{string} (de)",
          approved: true)

      @commit.keys.each(&:recalculate_ready!)
    end
  end

  it "should localize a Storyboard file" do
    compiler = Compiler.new(@commit.reload)
    file     = compiler.localize

    entries = Hash.new
    Archive.read_open_memory(file.io.read, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
      while (entry = archive.next_header)
        expect(entry).to be_regular
        entries[entry.pathname] = archive.read_data.force_encoding('UTF-8')
      end
    end

    #entries.size.should >= 3
    #entries['apple/de-DE.lproj/example.storyboard'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'example-de.storyboard')))
    #entries['apple/de-DE.lproj/example3.storyboard'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'example3-de.storyboard')))
    #entries['apple/de-DE.lproj/no-translations.storyboard'].should eql(File.read(Rails.root.join('spec', 'fixtures', 'no-translations.storyboard')))
    #TODO re-enable when enabling CopiesIosResourcesWithoutTranslations

    expect(entries.size).to eq(2)
    expect(entries['apple/de-DE.lproj/example.storyboard']).to eql(File.read(Rails.root.join('spec', 'fixtures', 'example-de.storyboard')))
    expect(entries['apple/de-DE.lproj/example3.storyboard']).to eql(File.read(Rails.root.join('spec', 'fixtures', 'example3-de.storyboard')))
  end
end
