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

describe KeyAncestorsRecalculator do
  describe "#perform" do
    context "Article" do
      it "recalculates the readiness of the related Article" do
        project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
        article = FactoryGirl.create(:article, project: project, ready: false, sections_hash: {"main" => "hi"})
        expect(article.reload.keys.length).to eql(1)
        key = article.keys.first
        expect(key).to_not be_ready
        expect(article).to_not be_ready
        expect(key.article).to eql(article)

        expect(KeyAncestorsRecalculator).to receive(:perform_once).once.and_call_original
        key.translations.in_locale(Locale.from_rfc5646('fr')).first.update! copy: "hi", approved: true
        key.recalculate_ready!

        expect(key.reload).to be_ready
        expect(article.reload).to be_ready
      end
    end

    context "Commits" do
      it "recalculates the readiness of the related Commits" do
        project = FactoryGirl.create(:project)
        commit1 = FactoryGirl.create(:commit, project: project, ready: false)
        commit2 = FactoryGirl.create(:commit, project: project, ready: false)
        key = FactoryGirl.create(:key, project: project, ready: false)
        commit1.keys = commit2.keys = [key]

        expect(KeyAncestorsRecalculator).to receive(:perform_once).once.and_call_original
        key.recalculate_ready!

        expect(commit1.reload).to be_ready
        expect(commit2.reload).to be_ready
      end
    end
  end
end
