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

describe ProjectTranslationAdderForKeyGroups do
  describe "#perform" do
    it "imports Projects's KeyGroups that inherit targeted_rfc5646_locales from Project, ignores the ones that don't inherit or don't belong to this project" do
      project = FactoryGirl.create(:project, repository_url: nil)
      key_group1 = FactoryGirl.create(:key_group, project: project)
      key_group2 = FactoryGirl.create(:key_group, project: project)
      key_group3 = FactoryGirl.create(:key_group, project: project, targeted_rfc5646_locales: { 'fr' => true }) # doesn't inherit
      key_group4 = FactoryGirl.create(:key_group) # not associated with this project
      key_group5 = FactoryGirl.create(:key_group).tap {|kg| kg.update! last_import_requested_at: 10.minutes.ago, last_import_finished_at: nil} # the first import is not finished
      key_group6 = FactoryGirl.create(:key_group).tap {|kg| kg.update! last_import_requested_at: 10.minutes.ago, last_import_finished_at: 15.minutes.ago} # some import other than the first one is not finished

      expect(KeyGroupImporter).to receive(:perform_once).with(key_group1.id)
      expect(KeyGroupImporter).to receive(:perform_once).with(key_group2.id)
      expect(KeyGroupImporter).to_not receive(:perform_once).with(key_group3.id)
      expect(KeyGroupImporter).to_not receive(:perform_once).with(key_group4.id)
      expect(KeyGroupImporter).to_not receive(:perform_once).with(key_group5.id)
      expect(KeyGroupImporter).to_not receive(:perform_once).with(key_group6.id)
      ProjectTranslationAdderForKeyGroups.new.perform(project.id)
    end
  end
end
