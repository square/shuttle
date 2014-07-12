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

describe AutoImporter do
  describe "#perform" do
    context "[watched branches]"
      it "calls ProjectAutoImporter on the projects with watched_branches, removes the watched branch if it doesn't exist" do
        Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
        project1 = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, watched_branches: %w(master non_existent_branch))
        project2 = FactoryGirl.create(:project, watched_branches: [])

        expect(project1.watched_branches).to eql(%w(master non_existent_branch))
        expect(project2.watched_branches).to be_blank
        expect(AutoImporter::ProjectAutoImporter).to receive(:perform_once).once.with(project1.id).and_call_original
        expect(AutoImporter::ProjectAutoImporter).to_not receive(:perform_once).with(project2.id)

        expect { AutoImporter.new.perform }.to_not raise_error

        expect(project1.reload.watched_branches).to eql(%w(master))
        expect(project2.reload.watched_branches).to be_blank
      end
  end
end

describe AutoImporter::ProjectAutoImporter do
  describe "#perform" do
    context "[watched branches]" do
      context "[rescue Git::CommitNotFoundError]" do
        it "removes a watched branch if the branch doesn't exist anymore" do
          Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
          project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, watched_branches: %w(master non_existent_branch))

          expect(project.watched_branches).to eql(%w(master non_existent_branch))
          expect { AutoImporter::ProjectAutoImporter.new.perform(project.id) }.to_not raise_error
          expect(project.reload.watched_branches).to eql(%w(master))
        end
      end
    end
  end
end
