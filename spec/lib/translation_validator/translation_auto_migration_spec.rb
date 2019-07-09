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

RSpec.describe TranslationValidator::TranslationAutoMigration do
  let(:source_copy) { "this is a testing string"}

  before :each do
    @project = FactoryBot.create(:project)
    @commit = FactoryBot.create(:commit, project: @project, author: 'Foo Bar', author_email: "foo@example.com")

    @key = FactoryBot.create(:key, project: @project, source_copy: source_copy)
    @commit.keys << @key

    @translation = FactoryBot.create(:translation, key: @key, source_copy: source_copy, copy: nil, translated: false, source_rfc5646_locale: 'en', rfc5646_locale: 'en-CA')
    @key.translations << @translation
  end

  describe "#run" do
    subject { TranslationValidator::TranslationAutoMigration.new(@commit).run }

    context "without any matched translation" do
      it "should not migrate TM" do
        subject

        @translation.reload
        expect(@translation.translated).to be_falsey
        expect(@translation.approved).to be_falsey
        expect(@translation.copy).to be_nil
        expect(@translation.notes).to be_nil
      end
    end

    context "with non-approved translation" do
      it "should not migrate TM" do
        key = FactoryBot.create(:key, project: @project, original_key: '1', source_copy: source_copy)
        FactoryBot.create(:translation, key: key, source_copy: source_copy, copy: 'hello', translated: true, approved: nil, source_rfc5646_locale: 'en', rfc5646_locale: 'en-CA')

        subject

        @translation.reload
        expect(@translation.translated).to be_falsey
        expect(@translation.approved).to be_falsey
        expect(@translation.copy).to be_nil
        expect(@translation.notes).to be_nil
      end
    end

    context "with approved translation" do
      it "should migrate TM" do
        key = FactoryBot.create(:key, project: @project, original_key: '1', source_copy: source_copy)
        translation = FactoryBot.create(:translation, key: key, source_copy: source_copy, copy: 'hello', translated: true, approved: true, source_rfc5646_locale: 'en', rfc5646_locale: 'en-CA')

        subject

        @translation.reload
        expect(@translation.translated).to be_truthy
        expect(@translation.approved).to be_falsey
        expect(@translation.copy).to eq('hello')
        expect(@translation.notes).to eq("AutoTM:#{translation.id} ")
      end
    end
  end
end
