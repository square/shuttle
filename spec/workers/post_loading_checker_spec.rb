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

require 'rails_helper'

RSpec.describe PostLoadingChecker do
  describe "#perform" do
    before :each do
      @project = FactoryBot.create(:project)
      @commit = FactoryBot.create(:commit, project: @project, author: 'Foo Bar', author_email: "foo@example.com")
    end

    it "calls each validator" do
      expect_any_instance_of(TranslationValidator::SourceFencerValidator).to receive(:run)
      expect_any_instance_of(TranslationValidator::TranslationAutoMigration).to receive(:run)

      PostLoadingChecker.new.perform('commit', @commit.id)
    end
  end
end
