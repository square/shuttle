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

describe Importer::NSLocalizedString do
  context "[importing]" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    only_paths:     %w(apple/),
                                    skip_imports:   Importer::Base.implementations.map(&:ident) - %w(ns_localized_string))
      @commit  = @project.commit!('HEAD')
    end

    it "should import strings from .strings files" do
      {
          'test.m'  => [
              ["Basic example", "Basic example context"],
              ["Example with newlines", "Example with newlines context"],
              ["Nil context", nil],
              ["NULL context", nil],
              ["0L context", nil],
              ["0 context", nil],
              ["Basic CF example", "CF example context"],
              ["CF example with newlines", "CF example newlines context"],
              ["String in table", "table context"],
              ["CF String in table", "CF table context"],
              ["String table bundle", "table bundle context"],
              ["CF string table bundle", "CF table bundle context"],
              ["String table bundle val", "table bundle context", "custom value"],
              ["CF string table bundle val", "CF table bundle context", "CF custom value"]
          ],
          'test.mm' => [
              ["Objective-C++ example", "Objective-C++ context"],
              ["Lots\n of \"special\" \t characters.\r", nil],
              [%|printf ("Characters: %c %c \n", 'a', 65);|, "printf context", %|printf ("Characters: %1$c %2$c \n", 'a', 65);|]
          ]
      }.each do |file, strings|
        strings.each do |(key, context, value)|
          value   ||= key
          key_obj = @project.keys.for_key("/apple/NSLocalizedString/#{file}:#{key}:#{context}").first
          key_obj.should_not be_nil
          key_obj.context.should eql(context)
          key_obj.translations.find_by_rfc5646_locale('en-US').copy.should eql(value)
        end
      end
    end
  end
end
