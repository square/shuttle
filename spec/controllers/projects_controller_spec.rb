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

describe ProjectsController do
  describe '#update' do
    context "[git-based]" do
      before :each do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        @user = FactoryGirl.create(:user, role: 'monitor')
        sign_in @user

        @project = FactoryGirl.create(:project, :light, targeted_rfc5646_locales: {'es'=>true, 'fr'=>true}, base_rfc5646_locale: 'en')
        @key1 = FactoryGirl.create(:key, key: "firstkey",  project: @project)
        @key2 = FactoryGirl.create(:key, key: "secondkey", project: @project)
        @commit = FactoryGirl.create(:commit, project: @project)
        @commit.keys = [@key1, @key2]

        @project.keys.each do |key|
          FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'en', source_copy: 'fake', copy: 'fake', approved: true)
          FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'es', source_copy: 'fake', copy: 'fake', approved: true)
          FactoryGirl.create(:translation, key: key, source_rfc5646_locale: 'en', rfc5646_locale: 'fr', source_copy: 'fake', copy: nil, approved: nil)
          key.recalculate_ready!
          expect(key).to_not be_ready
        end
      end

      it "runs ProjectTranslationAdder which adds missing translations when a new locale is added" do
        expect(ProjectTranslationAdder).to receive(:perform_once).and_call_original
        patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es fr ja}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }
        expect(@project.reload.translations.map(&:rfc5646_locale).sort).to eql(%w(en en es es fr fr ja ja))
      end

      it "switches keys' and commit's readiness from true to false when a new locale is added to a ready commit" do
        @project.translations.where(translated: false).each { |t| t.update! copy: 'fake', approved: true }
        @project.keys.each { |k| k.recalculate_ready! }
        @commit.recalculate_ready!
        expect(@commit.reload).to be_ready
        @project.reload.keys.each { |k| expect(k).to be_ready }

        patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es fr ja}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }

        expect(@commit.reload).to_not be_ready
        @project.reload.keys.each { |k| expect(k).to_not be_ready }
      end

      it "switches keys' and commit's readiness from false to true when a locale is removed and the remaining translations were already approved" do
        @commit.recalculate_ready!
        expect(@commit.reload).to_not be_ready

        patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }

        expect(@commit.reload).to be_ready
        @project.reload.keys.each { |k| expect(k).to be_ready }
      end
    end
  end

  describe '#github_webhook' do
    before :each do
      @project = FactoryGirl.create(:project, :light, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s, watched_branches: [ 'master' ])
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, role: 'monitor')
      sign_in @user
      @request.accept = "application/json"
      post :github_webhook, { id: @project.to_param, payload: "{\"ref\":\"refs/head/master\",\"after\":\"HEAD\"}" }
    end

    it "should return 200 and create a github commit for the current user" do
      expect(response.status).to eql(200)
      expect(@project.commits.first.user).to eql(@user)
      expect(@project.commits.first.description).to eql('github webhook')
    end
  end

  describe '#stash_webhook' do
    it "returns 200 if project has a repository_url" do
      project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      expect(CommitCreator).to receive(:perform_once).once
      post :stash_webhook, { id: project.to_param, sha: "HEAD" }
      expect(response).to be_ok
    end

    it "returns 400 if project doesn't have a repository_url" do
      project = Project.create(name: "Test")
      expect(CommitCreator).to_not receive(:perform_once)
      post :stash_webhook, { id: project.to_param, sha: "HEAD" }
      expect(response.status).to eql(400)
    end
  end
end
