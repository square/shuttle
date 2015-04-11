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
  render_views

  describe '#create' do
    context "[monitor role]" do
      before :each do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        @user = FactoryGirl.create(:user, :activated, :monitor)
        sign_in @user

        @base_rfc5646_locale = 'en'
        @project_params = FactoryGirl.attributes_for(:project, :light, base_rfc5646_locale: @base_rfc5646_locale).
                            except(:targeted_rfc5646_locales, :validate_repo_connectivity)
      end

      it "sets the targeted rfc5646 locales to the base locale regardless of input" do
        post :create, { project: @project_params.merge({required_rfc5646_locales: %w{es fr}, other_rfc5646_locales: %w{ja}, use_imports: Importer::Base.implementations.map(&:ident)}) }
        expect(Project.count).to eql(1)
        project = Project.last
        expect(project.targeted_rfc5646_locales).to eql({@base_rfc5646_locale => true})
      end
    end

    context "[admin role]" do
      before :each do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        @user = FactoryGirl.create(:user, :activated, :admin)
        sign_in @user

        @base_rfc5646_locale = 'en'
        @project_params = FactoryGirl.attributes_for(:project, :light, base_rfc5646_locale: @base_rfc5646_locale).
                            except(:targeted_rfc5646_locales, :validate_repo_connectivity)
      end

      it "sets the targeted rfc5646 locales to the base locale regardless of input" do
        post :create, { project: @project_params.merge({required_rfc5646_locales: %w{es fr}, other_rfc5646_locales: %w{ja}, use_imports: Importer::Base.implementations.map(&:ident)}) }
        expect(Project.count).to eql(1)
        project = Project.last
        expect(project.targeted_rfc5646_locales).to eql({'es' => true, 'fr' => true, 'ja' => false})
      end
    end
  end

  describe '#update' do
    %i(monitor reviewer).each do |role|
      context "[#{role} role]" do
        before :each do
          @request.env['devise.mapping'] = Devise.mappings[:user]
          @user = FactoryGirl.create(:user, :activated, role)
          sign_in @user

          @project = FactoryGirl.create(:project, :light, repository_url: nil, name: "test1")
        end

        it "can update basic attributes such as name" do
          patch :update, { id: @project.to_param, project: { name: "test2", use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }
          expect(@project.reload.name).to eql("test2")
        end
      end
    end

    context "[rfc5646 locales]" do
      %i(monitor reviewer).each do |role|
        context "[#{role} role]" do
          before :each do
            @request.env['devise.mapping'] = Devise.mappings[:user]
            @user = FactoryGirl.create(:user, :activated, role)
            sign_in @user

            @project = FactoryGirl.create(:project, :light, targeted_rfc5646_locales: {'fr'=>true}, base_rfc5646_locale: 'en')
          end

          it "retains the same targeted rfc5646 locales" do
            patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es fr}, other_rfc5646_locales: %w{ja}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }
            expect(@project.reload.targeted_rfc5646_locales).to eql({'fr' => true})
          end
        end
      end

      context "[admin role]" do
        before :each do
          @request.env['devise.mapping'] = Devise.mappings[:user]
          @user = FactoryGirl.create(:user, :activated, :admin)
          sign_in @user

          @project = FactoryGirl.create(:project, :light, targeted_rfc5646_locales: {'fr'=>true}, base_rfc5646_locale: 'en')
        end

        it "updates targeted rfc5646 locales" do
          patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es fr}, other_rfc5646_locales: %w{ja}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }
          expect(@project.reload.targeted_rfc5646_locales).to eql({'es' => true, 'fr' => true, 'ja' => false})
        end
      end
    end

    context "[git-based]" do
      before :each do
        @request.env['devise.mapping'] = Devise.mappings[:user]
        @user = FactoryGirl.create(:user, :activated, :admin)
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

      it "runs ProjectTranslationsAdderAndRemover which adds missing translations when a new locale is added" do
        expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once).and_call_original
        patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es fr ja}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }
        expect(@project.reload.translations.map(&:rfc5646_locale).sort).to eql(%w(en en es es fr fr ja ja))
      end

      it "runs ProjectTranslationsAdderAndRemover which removes unnecessary translations when a locale is removed" do
        expect(ProjectTranslationsAdderAndRemover).to receive(:perform_once).and_call_original
        patch :update, { id: @project.to_param, project: { required_rfc5646_locales: %w{es ja}, use_imports: (Importer::Base.implementations.map(&:ident) - @project.skip_imports) } }
        expect(@project.reload.translations.map(&:rfc5646_locale).sort).to eql(%w(en en es es ja ja))
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
      @user = FactoryGirl.create(:user, :activated)
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
      project = FactoryGirl.create(:project, repository_url: nil)
      expect(CommitCreator).to_not receive(:perform_once)
      post :stash_webhook, { id: project.to_param, sha: "HEAD" }
      expect(response.status).to eql(400)
    end
  end

  describe "#setup_mass_copy_translations" do
    before :each do
      @project = FactoryGirl.create(:project)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, :confirmed, role: 'admin')
      sign_in @user
    end

    it "doesn't let non-admins access this feature" do
      %w(monitor translator reviewer).each do |role|
        @user.update! role: role
        expect( get(:setup_mass_copy_translations, { id: @project.to_param }) ).to redirect_to(root_url)
      end
    end

    it "warns the user that this tool should be handled with care" do
      get :setup_mass_copy_translations, { id: @project.to_param }
      expect(response.body).to include("Important ReadMe",
                                       "Please make sure that you understand what this tool will do, by reading all of this readme.",
                                       "This tool will copy all approved translations from 'from' locale into not-translated 'to' locale.")
    end
  end

  describe "#mass_copy_translations" do
    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, :confirmed, role: 'admin')
      sign_in @user
    end

    it "doesn't let non-admins access this feature" do
      %w(monitor translator reviewer).each do |role|
        @user.update! role: role
        expect( post(:mass_copy_translations, { id: FactoryGirl.create(:project).to_param }) ).to redirect_to(root_url)
      end
    end

    it "doesn't perform ProjectTranslationsMassCopier and renders the current page again with errors if there is something wrong with the inputed locales" do
      project = FactoryGirl.create(:project, base_rfc5646_locale: 'en', targeted_rfc5646_locales: {'es-US'=>true} )
      expect(ProjectTranslationsMassCopier).to_not receive(:perform_once)
      post :mass_copy_translations, { id: project.to_param, from_rfc5646_locale: 'en', to_rfc5646_locale: 'es-US' }
      expect(response).to render_template("setup_mass_copy_translations")
      expect(request.flash.now[:alert]).to eql(["Failure. Not copying translations.", "Source and target locales are not in the same language family (their ISO639s do not match)"])
    end

    it "performs ProjectTranslationsMassCopier which copies all appropriate translations, updates keys and commits readiness states; redirects to the same page with success message" do
      project = FactoryGirl.create(:project,
                                   repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                   base_rfc5646_locale: 'en',
                                   targeted_rfc5646_locales: { 'fr' => true, 'fr-CA' => true, 'es-US' => false},
                                   skip_imports: (Importer::Base.implementations.map(&:ident) - %w(android)))
      project.commit!('a26f7f6a09aa362ff777c0bec11fa084e66efe64')
      commit = Commit.for_revision('a26f7f6a09aa362ff777c0bec11fa084e66efe64').last

      fr_translations = project.translations.where(rfc5646_locale: 'fr')
      fr_ca_translations = project.translations.where(rfc5646_locale: 'fr-CA')
      fr_translations.each { |t| t.update! copy: "#{t.source_copy} - autotranslated", approved: true } # assume all fr translations are done

      expect(commit).to_not be_ready
      commit.keys.each { |key| expect(key).to_not be_ready }
      expect(fr_ca_translations.not_translated.count).to eql(14)

      expect(ProjectTranslationsMassCopier).to receive(:perform_once).and_call_original

      post :mass_copy_translations, { id: project.to_param, from_rfc5646_locale: 'fr', to_rfc5646_locale: 'fr-CA' }
      expect(response).to redirect_to(mass_copy_translations_project_url(project))
      expect(request.flash[:success]).to eql("Success. Shuttle is now mass copying translations from fr to fr-CA.")

      expect(commit.reload).to be_ready
      commit.keys.each { |key| expect(key).to be_ready }
      expect(fr_ca_translations.not_translated.count).to eql(0)
      expect(fr_ca_translations.approved.count).to eql(14)
      expect(fr_translations.map(&:copy).sort).to eql(fr_ca_translations.reload.map(&:copy).sort)
    end

    it "doesn't override already translated translations" do
      project = FactoryGirl.create(:project, :light,
                                   base_rfc5646_locale: 'en',
                                   targeted_rfc5646_locales: { 'en-US' => true, 'en-CA' => true})
      project.commit!('fb355bb396eb3cf66e833605c835009d77054b71')
      commit = Commit.for_revision('fb355bb396eb3cf66e833605c835009d77054b71').last
      en_us_translation = project.translations.where(rfc5646_locale: 'en-US').last
      en_ca_translation = project.translations.where(rfc5646_locale: 'en-CA').last
      en_us_translation.update! copy: "this is definitely fake"

      post :mass_copy_translations, { id: project.to_param, from_rfc5646_locale: 'en', to_rfc5646_locale: 'en-CA' }
      post :mass_copy_translations, { id: project.to_param, from_rfc5646_locale: 'en', to_rfc5646_locale: 'en-US' }

      expect(en_us_translation.reload.copy).to eql("this is definitely fake")
      expect(en_ca_translation.reload.copy).to eql("enroot")
    end
  end
end
