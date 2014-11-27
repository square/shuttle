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

describe Importer::Erb do
  context "[importing]" do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(ruby/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(erb))
      @commit  = @project.commit!('HEAD')
    end

    it "should import one big string from an ERb file" do
      file = @project.repo.object('HEAD^{tree}:ruby/example.en-US.text.erb').contents
      expect(@project.keys.for_key('/ruby/example.text.erb').first.translations.find_by_rfc5646_locale('en-US').copy).to eql(file)
    end

    it "should fence HTML tags in HTML ERB files" do
      file        = @project.repo.object('HEAD^{tree}:ruby/example.en-US.html.erb').contents
      translation = @project.keys.for_key('/ruby/example.html.erb').first.translations.find_by_rfc5646_locale('en-US')
      expect(translation.copy).to eql(file)
      expect(translation.fences).to eql(
                                    '<%= something %>' => [22..37],
                                    '<b>'              => [5..7],
                                    '</b>'             => [12..15]
                                )
    end
  end
end
