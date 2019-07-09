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

RSpec.describe TranslationValidator::SourceFencerValidator do
  let(:source_copy) { "this is a {{good-variable-name}}"}

  before :each do
    @project = FactoryBot.create(:project)
    @commit = FactoryBot.create(:commit, project: @project, author: 'Foo Bar', author_email: "foo@example.com")

    @key = FactoryBot.create(:key, project: @project, fencers: ['Mustache'], source_copy: source_copy)
    @commit.keys << @key

    @translation = FactoryBot.create(:translation, key: @key, translated: false, copy: nil)
    @key.translations << @translation
  end

  describe "#run" do
    subject { TranslationValidator::SourceFencerValidator.new(@commit).run }

    context "without suspicious source strings" do
      it "should not send email" do
        expect_any_instance_of(FencerValidationMailer).to_not receive(:suspicious_source_found)

        subject
      end
    end

    context "with suspicious source strings" do
      let(:source_copy) { "this is a {{bad variable name}}" }

      it "should send email" do
        expect_any_instance_of(FencerValidationMailer).to receive(:suspicious_source_found)

        subject
      end
    end
  end
end
