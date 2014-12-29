# encoding: utf-8

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

describe Api::V1::ArticlesController do
  let(:project) { FactoryGirl.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
  let(:monitor_user) { FactoryGirl.create(:user, :confirmed, role: 'monitor') }

  def sign_in_monitor_user
    request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in monitor_user
  end

  shared_examples_for "api-or-session-authenticateable-and-filters" do |options={}|
    options = { runs_find_article_filter: true, accepts_json_request: true, accepts_html_request: true }.merge(options)

    context "[format=JSON]" do
      if options[:accepts_json_request]
        context "[auth with api_token]" do
          it "errors with API error message if wrong api_token is provided" do
            send request_type, action, params.merge(project_id: project.id, format: :json, api_token: "fake")
            expect(response.status).to eql(401)
            expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"Invalid project API TOKEN"}]}})
          end

          it "authenticates with api_token" do
            send request_type, action, params.merge(project_id: project.id, format: :json, api_token: project.api_token)
            expect(assigns(:project)).to eq(project) # if @project is set, it means authentication was successful
          end
        end

        context "[auth without api_token]" do
          it "errors with non-API error message if there is no signed in user" do
            send request_type, action, params.merge(project_id: project.id, format: :json)
            expect(response.status).to eql(401)
            expect(JSON.parse(response.body)).to eql({"error"=>"You need to sign in or sign up before continuing."})
          end

          it "authenticates with session if there is a signed in user" do
            sign_in_monitor_user
            send request_type, action, params.merge(project_id: project.id, format: :json)
            expect(assigns(:project)).to eq(project) # if @project is set, it means authentication was successful
          end
        end

        it "errors with project-not-found message if project_id is invalid (only makes sense with session-auth; because for API-auth, it would error with invalid-token-api message)" do
          sign_in_monitor_user
          send request_type, action, params.merge(project_id: -1, format: :json)
          expect(assigns(:project)).to be_nil
          expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"Invalid project"}]}})
        end

        if options[:runs_find_article_filter] # find_article before_filter is not run for all actions
          it "errors with article-not-found message if article_id is invalid (auth method shouldn't matter)" do
            send request_type, action, params.merge(project_id: project.id, name: 'fakeyfake', format: :json, api_token: project.api_token)
            expect(assigns(:project)).to eql(project)
            expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"Article doesn't exist"}]}})
          end
        end
      else
        it "errors with ActionController::UnknownFormat if json format is not supported" do
          expect { send request_type, action, params.merge(project_id: project.id, format: :json, api_token: project.api_token) }.to raise_error(ActionController::UnknownFormat)
        end
      end
    end

    context "[format=HTML]" do
      if options[:accepts_html_request]
        context "[auth without api_token]" do
          it "redirects if there is no signed in user" do
            send request_type, action, params.merge(project_id: project.id, format: :html)
            expect(response).to be_redirect
          end

          it "authenticates with session" do
            sign_in_monitor_user
            send request_type, action, params.merge(project_id: project.id, format: :html)
            expect(assigns(:project)).to eq(project) # if @project is set, it means authentication was successful
          end
        end

        it "errors with project-not-found message if project_id is invalid (only makes sense with session-auth; because for API-auth, it would error with invalid-token-api message)" do
          sign_in_monitor_user
          send request_type, action, params.merge(project_id: -1, format: :html)
          expect(assigns(:project)).to be_nil
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eql("Invalid project")
        end

        if options[:runs_find_article_filter] # find_article before_filter is not run for all actions
          it "errors with article-not-found message if article_id is invalid (auth method shouldn't matter)" do
            send request_type, action, params.merge(project_id: project.id, name: 'fakeyfake', format: :html, api_token: project.api_token)
            expect(assigns(:project)).to eql(project)
            expect(response).to redirect_to(root_path)
            expect(flash[:alert]).to eql("Article doesn't exist")
          end
        end
      else
        it "errors with ActionController::UnknownFormat if html format is not supported" do
          sign_in_monitor_user
          expect { send request_type, action, params.merge(project_id: project.id, format: :html) }.to raise_error(ActionController::UnknownFormat)
        end
      end
    end
  end

  describe "#index" do
    it_behaves_like "api-or-session-authenticateable-and-filters", runs_find_article_filter: false, accepts_html_request: false do
      let(:request_type) { :get }
      let(:action) { :index }
      let(:params) { {} }
    end

    it "retrieves all Articles in the project, but not the Articles in other projects" do
      Article.any_instance.stub(:import!) # prevent auto imports
      project = FactoryGirl.create(:project, repository_url: nil)
      article1 = FactoryGirl.create(:article, project: project)
      article2 = FactoryGirl.create(:article, project: project)
      article2.update! ready: true

      2.times { FactoryGirl.create(:article) }

      get :index, project_id: project.id, api_token: project.api_token, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql([{"name"=>article1.name, "ready"=>false}, {"name"=>article2.name, "ready"=>true}])
    end
  end

  describe "#new" do
    it_behaves_like "api-or-session-authenticateable-and-filters", runs_find_article_filter: false, accepts_json_request: false do
      let(:request_type) { :get }
      let(:action) { :new }
      let(:params) { { } }
    end
  end

  describe "#create" do
    it_behaves_like "api-or-session-authenticateable-and-filters", runs_find_article_filter: false do
      let(:request_type) { :post }
      let(:action) { :create }
      let(:params) { { article: { name: "" } } } # so that it doesn't fail because `article` param is missing
    end

    it "doesn't create a Article without a name or source_copy, shows the errors to user" do
      post :create, project_id: project.id, api_token: project.api_token, article: {name: ""}, format: :json
      expect(response.status).to eql(400)
      expect(Article.count).to eql(0)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{ "name"=>["can’t be blank"], "sections_hash"=>["can’t be blank"]}}})
    end

    it "creates an Article, its Sections, inherits locale settings from Project" do
      post :create, project_id: project.id, api_token: project.api_token, article: { name: "testname", sections_hash: {"title" => "<p>a</p><p>b</p>", "body" => "<p>a</p><p>c</p>"}}, format: :json
      expect(response.status).to eql(200)
      expect(Article.count).to eql(1)
      article = Article.last
      expect(article.name).to eql("testname")
      expect(article.sections.map { |section| [section.name, section.source_copy, section.active] }.sort).to eql([["title", "<p>a</p><p>b</p>", true], ["body", "<p>a</p><p>c</p>", true]].sort)
      expect(article.keys.count).to eql(4)
      expect(article.translations.count).to eql(12)
      expect(article.base_rfc5646_locale).to eql('en')
      expect(article.targeted_rfc5646_locales).to eql({ 'fr' => true, 'es' => false })
      expect(article.base_locale).to eql(Locale.from_rfc5646('en'))
      expect(article.targeted_locales.map(&:rfc5646).sort).to eql(%w(es fr).sort)
    end

    it "creates an Article, has its own locale settings different from those of Project's" do
      post :create, project_id: project.id, api_token: project.api_token, article: { name: "testname", sections_hash: {"title" => "<p>a</p><p>b</p>"}, base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: { 'ja' => true }}, format: :json
      expect(response.status).to eql(200)
      expect(Article.count).to eql(1)
      article = Article.last
      expect(article.keys.count).to eql(2)
      expect(article.translations.count).to eql(4)
      expect(article.base_rfc5646_locale).to eql('en-US')
      expect(article.targeted_rfc5646_locales).to eql({ 'ja' => true })
      expect(article.base_locale).to eql(Locale.from_rfc5646('en-US'))
      expect(article.targeted_locales.map(&:rfc5646)).to eql(%w(ja))
    end

    it "doesn't create a Article in a Project with a duplicate key name" do
      FactoryGirl.create(:article, project: project, name: "testname", sections_hash: {"title" => "<p>a</p><p>b</p>"})
      post :create, project_id: project.id, api_token: project.api_token, article: { name: "testname", sections_hash: {"title" => "<p>a</p><p>b</p>"}}, format: :json
      expect(response.status).to eql(400)
      expect(Article.count).to eql(1)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"name"=>["already taken"]}}})
    end

    context "[API_REQUEST]" do
      before(:each) do
        expect(Article.count).to eql(0)
      end

      it "sets creator to nil" do
        post :create, project_id: project.id, api_token: project.api_token, article: { name: "test", sections_hash: {"title" => "hello"}}, format: :json
        expect(Article.last.creator).to be_nil
      end

      it "sets created_via_api to true" do
        post :create, project_id: project.id, api_token: project.api_token, article: { name: "test", sections_hash: {"title" => "hello"}}, format: :json
        expect(Article.last.created_via_api).to be_true
      end
    end

    context "[NOT API_REQUEST]" do
      before(:each) do
        sign_in_monitor_user
        expect(Article.count).to eql(0)
      end

      it "sets creator & updater to current_user" do
        post :create, project_id: project.id, article: { name: "test", sections_hash: {"title" => "hello"}}, format: :json
        expect(Article.last.creator).to eql(monitor_user)
        expect(Article.last.updater).to eql(monitor_user)
      end

      it "sets created_via_api to false" do
        post :create, project_id: project.id, article: { name: "test", sections_hash: {"title" => "hello"}}, format: :json
        expect(Article.last.created_via_api).to be_false
      end
    end
  end

  describe "#show" do
    let(:article) { FactoryGirl.create(:article, project: project, name: "test", sections_hash: {"main" => "<p>a</p><p>b</p>"}) }

    it_behaves_like "api-or-session-authenticateable-and-filters" do
      let(:request_type) { :get }
      let(:action) { :show }
      let(:params) { { name: article.name } }
    end

    it "shows details of an Article" do
      get :show, project_id: project.id, api_token: project.api_token, name: article.name, format: :json

      expect(response.status).to eql(200)
      response_json = JSON.parse(response.body)
      expect(response_json["sections_hash"]).to eql({"main"=>"<p>a</p><p>b</p>"})
    end
  end

  describe "#edit" do
    let(:article) { FactoryGirl.create(:article, project: project, name: "test", sections_hash: {"main" => "<p>a</p><p>b</p>"}) }

    it_behaves_like "api-or-session-authenticateable-and-filters", accepts_json_request: false do
      let(:request_type) { :get }
      let(:action) { :edit }
      let(:params) { { name: article.name } }
    end
  end

  describe "#update" do
    let(:article) { FactoryGirl.create(:article, project: project, name: "test", sections_hash: { "main" => "<p>a</p><p>b</p>", "second" => "<p>y</p><p>z</p>", "third" => "<p>t</p>" }).tap(&:reload) }

    it_behaves_like "api-or-session-authenticateable-and-filters" do
      let(:request_type) { :patch }
      let(:action) { :update }
      let(:params) { { name: article.name, article: { name: article.name } } } # so that it doesn't fail because Article is not found or `article` param is missing
    end

    it "updates an Article's sections_hash and targeted_rfc5646_locales" do
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { sections_hash: { "main" => "<p>a</p><p>x</p><p>b</p>", "sub" => "<p>y</p><p>z</p>", "third" => "<p>t</p>" }, targeted_rfc5646_locales: { 'fr' => true, 'es' => false, 'tr' => false } }, format: :json
      expect(response.status).to eql(200)
      article = Article.first
      expect(article.sections.count).to eql(4)
      expect(article.active_sections.count).to eql(3)

      main_section = article.active_sections.for_name("main").first
      sub_section = article.active_sections.for_name("sub").first
      third_section = article.active_sections.for_name("third").first
      second_section = article.inactive_sections.for_name("second").first

      expect(main_section.keys.count).to eql(3)
      expect(main_section.translations.count).to eql(12) # a new locale is added with the update
      expect(sub_section.keys.count).to eql(2)
      expect(sub_section.translations.count).to eql(8)
      expect(third_section.keys.count).to eql(1)
      expect(third_section.translations.count).to eql(4)
      expect(second_section.keys.count).to eql(2)
      expect(second_section.translations.count).to eql(6) # since this is inactivated, this shouldn't have picked the new locale's translations
    end

    it "can update targeted_rfc5646_locales" do
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { targeted_rfc5646_locales: { 'fr' => true } }, format: :json
      expect(response.status).to eql(200)
      expect(Article.count).to eql(1)
      expect(article.reload.targeted_rfc5646_locales).to eql({ 'fr' => true })
    end

    it "can update source_copy without updating targeted_rfc5646_locales" do
      article.update! targeted_rfc5646_locales: { 'fr' => true }
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { sections_hash: { "main" => "<p>a</p><p>x</p><p>b</p>" } }, format: :json
      expect(response.status).to eql(200)
      expect(Article.count).to eql(1)
      expect(article.reload.targeted_rfc5646_locales).to eql({ 'fr' => true })
      expect(article.active_sections.pluck(:source_copy)).to eql(["<p>a</p><p>x</p><p>b</p>"])
    end

    it "errors if source copy is attempted to be updated before the first import didn't finish yet" do
      article.update! last_import_requested_at: 1.minute.ago, last_import_finished_at: nil
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { sections_hash: { "main" => "<p>a</p><p>x</p><p>b</p>" } }, format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"base"=>["latest requested import is not yet finished"]}}})
    end

    it "errors if source copy is attempted to be updated before a subsequent import didn't finish yet" do
      article.update! last_import_requested_at: 1.hour.ago, last_import_finished_at: 2.hours.ago
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { sections_hash: { "main" => "<p>a</p><p>x</p><p>b</p>" } }, format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"base"=>["latest requested import is not yet finished"]}}})
    end

    it "allows updating non-import related fields such as emails and description even if the previous import didn't finish yet" do
      article.update! last_import_requested_at: 1.hour.ago, last_import_finished_at: 2.hours.ago, email: "test@example.com", description: "test"
      expect(article.email).to eql("test@example.com")
      expect(article.description).to eql("test")
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { email: "test2@example.com", description: "test 2" }, format: :json
      expect(response.status).to eql(200)
      expect(article.reload.email).to eql("test2@example.com")
      expect(article.description).to eql("test 2")
    end

    it "errors if update fails" do
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { sections_hash: {}, email: "fake", targeted_rfc5646_locales: {'asdaf-sdfsfs-adas'=> nil}}, format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({ "error" => { "errors"=> { "sections_hash" => ["can’t be blank"], "email" => ["invalid"], "targeted_rfc5646_locales" => ["invalid"] } } })
    end

    context "[format=HTML]" do
      render_views

      it "the rendered form's action should point to the original name, if name is attempted to be updated, but couldn't" do
        sign_in_monitor_user
        patch :update, project_id: project.id, name: article.name, article: { name: "updated_name", sections_hash: {} }, format: :html # should fail
        expect(response.body).to include(api_v1_project_article_path(project.id, article.reload.name))
        expect(response.body).to_not include(api_v1_project_article_path(project.id, "updated_name"))
      end
    end

    context "[API_REQUEST]" do
      it "sets updater to nil" do
        patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { priority: 2 }, format: :json
        expect(Article.last.creator).to be_nil
      end
    end

    context "[NOT API_REQUEST]" do
      before(:each) { sign_in_monitor_user }

      it "sets updater to current_user" do
        patch :update, project_id: project.id, name: article.name, article: { priority: 2 }, format: :json
        expect(Article.last.updater).to eql(monitor_user)
      end

      it "doesn't change creator" do
        article.update creator_id: nil
        patch :update, project_id: project.id, name: article.name, article: { priority: 2 }, format: :json
        expect(Article.last.creator).to be_nil
      end
    end

  end

  describe "#manifest" do
    before(:each) { project.update! targeted_rfc5646_locales: { 'fr' => true, 'ja' => true, 'es' => false } }
    let(:article) { FactoryGirl.create(:article, project: project, name: "test", sections_hash: { "title" => "<p>hello</p>", "body" => "<p>a</p><p>b</p>" } ) }

    it_behaves_like "api-or-session-authenticateable-and-filters" do
      let(:request_type) { :get }
      let(:action) { :manifest }
      let(:params) { { name: article.name } }
    end

    it "errors if not all required locales are ready (i.e. translated)" do
      get :manifest, project_id: project.id, api_token: project.api_token, name: article.name, format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"#<Exporter::Article::NotReadyError: Exporter::Article::NotReadyError>"}]}})
    end

    it "downloads the manifest of a Article" do
      article.translations.in_locale(*article.required_locales).each do |translation|
        translation.update! copy: "<p>translated</p>", approved: true
      end
      article.keys.reload.each(&:recalculate_ready!)
      get :manifest, project_id: project.id, api_token: project.api_token, name: article.name, format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql({ "fr" => { "title" => "<p>translated</p>", "body" => "<p>translated</p><p>translated</p>" }, "ja" => { "title" => "<p>translated</p>", "body" => "<p>translated</p><p>translated</p>" } })
    end
  end

  describe "#issue" do
    let(:article) { FactoryGirl.create(:article, project: project) }

    it_behaves_like "api-or-session-authenticateable-and-filters" do
      let(:request_type) { :get }
      let(:action) { :issues }
      let(:params) { { name: article.name } }
    end

    it "returns issues and their stats" do
      translation1 = article.translations.first
      translation2 = article.translations.last
      FactoryGirl.create(:issue, translation: translation1)
      FactoryGirl.create(:issue, translation: translation2)

      get :issues, project_id: project.id, api_token: project.api_token, name: article.name, format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql(
        {
          "issues"=>[
            {"summary"=>"MyString", "description"=>"MyText", "priority"=>nil, "kind"=>1, "status"=>1, "subscribed_emails"=>[]},
            {"summary"=>"MyString", "description"=>"MyText", "priority"=>nil, "kind"=>1, "status"=>1, "subscribed_emails"=>[]}
          ],

          "status_counts"=>[
            {"status"=>1, "status_desc"=>"Open", "count"=>2},
            {"status"=>2, "status_desc"=>"In progress", "count"=>0},
            {"status"=>3, "status_desc"=>"Resolved", "count"=>0},
            {"status"=>4, "status_desc"=>"IceBox", "count"=>0}
          ]
        }
      )
    end

    it "doesn't return issues of inactive keys" do
      key = FactoryGirl.create(:key, section: article.sections.last, index_in_section: nil, project: article.project)
      translation = FactoryGirl.create(:translation, key: key)
      FactoryGirl.create(:issue, translation: translation)

      get :issues, project_id: project.id, api_token: project.api_token, name: article.name, format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql(
        {
          "issues"=>[],

          "status_counts"=>[
            {"status"=>1, "status_desc"=>"Open", "count"=>0},
            {"status"=>2, "status_desc"=>"In progress", "count"=>0},
            {"status"=>3, "status_desc"=>"Resolved", "count"=>0},
            {"status"=>4, "status_desc"=>"IceBox", "count"=>0}
          ]
        }
      )
    end
  end

  describe "#params_for_create" do
    it "permits name, base_rfc5646_locale, key, sections_hash, description, email, targeted_rfc5646_locales, due_date, priority; but not id or project_id fields" do
      post :create, project_id: project.id, api_token: project.api_token, article: {name: "t", due_date: "01/13/2015", priority: 1, sections_hash: { "t" => "t" }, description: "t", email: "t@example.com", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true }, id: 300}, format: :json
      expect(controller.send :params_for_create).to eql({ "name"=>"t", "due_date" => DateTime::strptime("01/13/2015", "%m/%d/%Y"), "priority" => 1, "name"=>"t", "sections_hash"=>{"t" => "t"}, "description"=>"t", "email"=>"t@example.com", "base_rfc5646_locale"=>"en", "targeted_rfc5646_locales"=>{"fr"=>true}, "created_via_api"=>true, "creator_id"=>nil, "updater_id"=>nil})
    end

    it "doesn't include sections_hash or targeted_rfc5646_locales in the permitted params (this is tested separately because it's a special case due to being a hash field)" do
      post :create, project_id: project.id, api_token: project.api_token, name: "t", article: { priority: 2 }, format: :json
      expect(controller.send(:params_for_create).key?("sections_hash")).to be_false
      expect(controller.send(:params_for_create).key?("targeted_rfc5646_locales")).to be_false
    end

    context "[API_REQUEST]" do
      it "sets creator_id to nil" do
        post :create, project_id: project.id, api_token: project.api_token, article: { priority: 1 }, format: :json
        params_for_create = controller.send(:params_for_create)
        expect(params_for_create["creator_id"]).to be_nil
        expect(params_for_create["updater_id"]).to be_nil
        expect(params_for_create["created_via_api"]).to be_true
      end
    end

    context "[NOT API_REQUEST]" do
      it "sets creator_id to current_user's id" do
        sign_in_monitor_user
        post :create, project_id: project.id, article: { priority: 1 }, format: :json
        params_for_create = controller.send(:params_for_create)
        expect(params_for_create["creator_id"]).to eql(monitor_user.id)
        expect(params_for_create["updater_id"]).to eql(monitor_user.id)
        expect(params_for_create["created_via_api"]).to be_false
      end
    end
  end

  describe "#params_for_update" do
    let(:article) { FactoryGirl.create(:article, project: project, name: "t") }

    it "permits name, sections_hash, description, email, targeted_rfc5646_locales, due_date, priority; but not id, project_id, key or base_rfc5646_locale fields" do
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { name: "t2", due_date: "01/13/2015", priority: 1, sections_hash: { "t" => "t" }, description: "t", email: "t@example.com", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true }, id: 300}, format: :json
      expect(controller.send :params_for_update).to eql({ "name" => "t2", "due_date" => DateTime::strptime("01/13/2015", "%m/%d/%Y"), "priority" => 1, "sections_hash" => { "t" => "t" }, "description"=>"t", "email"=>"t@example.com", "targeted_rfc5646_locales"=>{"fr"=>true}, "updater_id" => nil})
    end

    it "doesn't include sections_hash and targeted_rfc5646_locales in the permitted params (this is tested separately because it's a special case due to being a hash field)" do
      patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { priority: 2 }, format: :json
      expect(controller.send(:params_for_update).key?("sections_hash")).to be_false
      expect(controller.send(:params_for_update).key?("targeted_rfc5646_locales")).to be_false
    end

    context "[API_REQUEST]" do
      it "sets updater_id to nil" do
        patch :update, project_id: project.id, api_token: project.api_token, name: article.name, article: { priority: 1 }, format: :json
        expect(controller.send(:params_for_update)["updater_id"]).to be_nil
      end
    end

    context "[NOT API_REQUEST]" do
      it "sets updater_id to current_user's id" do
        sign_in_monitor_user
        patch :update, project_id: project.id, name: article.name, article: { priority: 1 }, format: :json
        expect(controller.send(:params_for_update)["updater_id"]).to eql(monitor_user.id)
      end
    end
  end

  describe "#api_request?" do
    it "returns true if api_token exists" do
      get :index, project_id: project.id, api_token: "test", format: :json
      expect(controller.send(:api_request?)).to be_true
    end

    it "returns false if api_token doesn't exist" do
      get :index, project_id: project.id, api_token: nil, format: :json
      expect(controller.send(:api_request?)).to be_false
    end
  end

  context "[INTEGRATION TESTS]" do
    # This is a real life example. sample_article__original.html was copied and pasted from the help center's website. it was shortened to make tests faster
    it "handles creation, update, update, status, manifest, status, manifest requests in that order" do
      Article.delete_all
      project = FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true } )

      # Create
      post :create, project_id: project.id, api_token: project.api_token, article: { name: "support-article", sections_hash: { "title" => "<p>AAA</p><p>BBB</p>", "banner" => "<p>XXX</p><p>YYY</p>", "main" => File.read(Rails.root.join('spec', 'fixtures', 'article_files', 'sample_article__original.html')) } }, format: :json
      expect(response.status).to eql(200)
      expect(Article.count).to eql(1)
      article = Article.first
      original_article_ids = article.keys.map(&:id)
      expect(article.active_sections.count).to eql(3)
      expect(article.inactive_sections.count).to eql(0)
      expect(article.keys.count).to eql(65)
      expect(article.active_keys.count).to eql(65)
      expect(article.translations.count).to eql(130)

      # Update: change targeted_rfc5646_locales. previously this defaulted to project settings, this time, put it into the Article
      patch :update, project_id: project.id, api_token: project.api_token, name: "support-article", article: { targeted_rfc5646_locales: { 'fr' => true, 'es' => false }}, format: :json
      expect(response.status).to eql(200)
      updated_article_ids = article.reload.keys.map(&:id)
      expect(article.active_sections.count).to eql(3)
      expect(article.inactive_sections.count).to eql(0)
      expect(article.keys.count).to eql(65)
      expect((updated_article_ids - original_article_ids).length).to eql(0) # to make sure that we reused the old keys
      expect(article.active_keys.count).to eql(65)
      expect(article.translations.count).to eql(195)

      # Update
      # this source copy has 1 changed word, 2 added divs one of which is a duplicate of an existing div, and 1 removed div
      patch :update, project_id: project.id, api_token: project.api_token, name: "support-article", article: { sections_hash: { "title" => "<p>AAA</p><p>GGG</p><p>BBB</p>", "header" => "<p>111</p>", "footer" => "<p>111</p>", "main" => File.read(Rails.root.join('spec', 'fixtures', 'article_files', 'sample_article__updated.html')) } }, format: :json
      expect(response.status).to eql(200)
      updated_article_ids = article.reload.keys.map(&:id)
      expect(article.active_sections.count).to eql(4)
      expect(article.inactive_sections.count).to eql(1)
      expect(article.keys.count).to eql(71) # +3 comes from file changes => 2 (addition) + 1 (change)
      expect((updated_article_ids - original_article_ids).length).to eql(6) # just to make sure that we reused the old keys
      expect(article.active_keys.count).to eql(67) # +1 comes from file changes => 2 (addition) - 1 (removal)
      expect(article.translations.count).to eql(213)

      # Manifest
      get :manifest, project_id: project.id, api_token: project.api_token, name: "support-article", format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"#<Exporter::Article::NotReadyError: Exporter::Article::NotReadyError>"}]}})

      # Assume all translations are done now
      article.reload.translations.where(approved: nil).each do |translation|
        translation.update! copy: "test", approved: true
      end
      article.keys.reload.each(&:recalculate_ready!)

      # Manifest
      get :manifest, project_id: project.id, api_token: project.api_token, name: "support-article", format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql({ "fr" => { "title" => "test"*3, "header" => "test", "footer" => "test", "main" => "test"*62 } })
    end
  end
end
