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
require 'rake'

describe 'maintenance' do
  subject { Rake::Task['maintenance:cleanup_commits'].invoke }

  before :all do
    Rake.application.rake_require "tasks/maintenance/cleanup_commits"
    Rake::Task.define_task(:environment)
  end

  describe 'cleanup_commits' do
    describe "#destroy_old_commits_which_errored_during_import" do
      it "deletes the errored Commits which are older than 2 days, keeps other errored Commits" do
        project = FactoryGirl.create(:project)
        standing = FactoryGirl.create(:commit, :errored_during_import, project: project, created_at: 47.hours.ago)
        FactoryGirl.create(:commit, :errored_during_import, project: project, created_at: 49.hours.ago)
        FactoryGirl.create(:commit, :errored_during_import, project: project, created_at: 72.hours.ago)

        subject
        expect(Commit.all.to_a).to eql([standing])
      end
    end
  end
end
