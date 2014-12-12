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

# Since InheritedSettingsForKey module is meant to be included in only {Key} model,
# it will be tested in the context of {Key} model.

require 'spec_helper'

describe InheritedSettingsForKey do
  describe "#required_locales" do
    it "returns Project's required locales for git-based Keys" do
      key = FactoryGirl.create(:key, article: nil)
      expect(key.required_locales).to eql(key.project.required_locales)
    end

    it "returns Article's required locales for Article-based Keys" do
      project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
      article = FactoryGirl.create(:article, project: project, targeted_rfc5646_locales: {'ja' => true})
      key = FactoryGirl.create(:key, article: article, project: project)
      expect(key.required_locales).to eql(article.required_locales)
    end
  end

  describe "#skip_key?" do
    it "calls's project's skip_key? method if key is git-based" do
      project = FactoryGirl.create(:project)
      key = FactoryGirl.create(:key, project: project, article: nil)
      expect(project).to receive(:skip_key?)
      key.skip_key?(Locale.from_rfc5646('en'))
    end

    it "calls's Article's skip_key? method if key is Article-based" do
      project = FactoryGirl.create(:project)
      article = FactoryGirl.create(:article, project: project)
      key = FactoryGirl.create(:key, article: article, project: project)
      expect(article).to receive(:skip_key?)
      expect(project).to_not receive(:skip_key?)
      key.skip_key?(Locale.from_rfc5646('en'))
    end
  end

  describe "#base_locale" do
    it "returns Project's base locale for git-based Keys" do
      key = FactoryGirl.create(:key, article: nil)
      expect(key.base_locale).to eql(key.project.base_locale)
    end

    it "returns Article's base locale for Article-based Keys" do
      project = FactoryGirl.create(:project, base_rfc5646_locale: 'fr')
      article = FactoryGirl.create(:article, project: project, base_rfc5646_locale: 'ja')
      key = FactoryGirl.create(:key, article: article, project: project)
      expect(key.base_locale).to eql(article.base_locale)
    end
  end

  describe "#targeted_locales" do
    it "returns Project's targeted locales for git-based Keys" do
      key = FactoryGirl.create(:key, article: nil)
      expect(key.targeted_locales).to eql(key.project.targeted_locales)
    end

    it "returns Article's targeted locales for Article-based Keys" do
      project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
      article = FactoryGirl.create(:article, project: project, targeted_rfc5646_locales: {'ja' => true})
      key = FactoryGirl.create(:key, article: article, project: project)
      expect(key.targeted_locales).to eql(article.targeted_locales)
    end
  end
end
