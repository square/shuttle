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
      key = FactoryGirl.create(:key, key_group: nil)
      expect(key.required_locales).to eql(key.project.required_locales)
    end

    it "returns KeyGroup's required locales for KeyGroup-based Keys" do
      project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
      key_group = FactoryGirl.create(:key_group, project: project, targeted_rfc5646_locales: {'ja' => true})
      key = FactoryGirl.create(:key, key_group: key_group, project: project)
      expect(key.required_locales).to eql(key_group.required_locales)
    end
  end

  describe "#skip_key?" do
    it "calls's project's skip_key? method if key is git-based" do
      project = FactoryGirl.create(:project)
      key = FactoryGirl.create(:key, project: project, key_group: nil)
      expect(project).to receive(:skip_key?)
      key.skip_key?(Locale.from_rfc5646('en'))
    end

    it "calls's key group's skip_key? method if key is keygroup-based" do
      project = FactoryGirl.create(:project)
      key_group = FactoryGirl.create(:key_group, project: project)
      key = FactoryGirl.create(:key, key_group: key_group, project: project)
      expect(key_group).to receive(:skip_key?)
      expect(project).to_not receive(:skip_key?)
      key.skip_key?(Locale.from_rfc5646('en'))
    end
  end

  describe "#base_locale" do
    it "returns Project's base locale for git-based Keys" do
      key = FactoryGirl.create(:key, key_group: nil)
      expect(key.base_locale).to eql(key.project.base_locale)
    end

    it "returns KeyGroup's base locale for KeyGroup-based Keys" do
      project = FactoryGirl.create(:project, base_rfc5646_locale: 'fr')
      key_group = FactoryGirl.create(:key_group, project: project, base_rfc5646_locale: 'ja')
      key = FactoryGirl.create(:key, key_group: key_group, project: project)
      expect(key.base_locale).to eql(key_group.base_locale)
    end
  end

  describe "#targeted_locales" do
    it "returns Project's targeted locales for git-based Keys" do
      key = FactoryGirl.create(:key, key_group: nil)
      expect(key.targeted_locales).to eql(key.project.targeted_locales)
    end

    it "returns KeyGroup's targeted locales for KeyGroup-based Keys" do
      project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
      key_group = FactoryGirl.create(:key_group, project: project, targeted_rfc5646_locales: {'ja' => true})
      key = FactoryGirl.create(:key, key_group: key_group, project: project)
      expect(key.targeted_locales).to eql(key_group.targeted_locales)
    end
  end
end
