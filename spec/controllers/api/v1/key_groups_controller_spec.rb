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

describe Api::V1::KeyGroupsController do
  def expect_invalid_api_token_response
    expect(response.status).to eql(401)
    expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"Invalid project API TOKEN"}]}})
  end

  shared_examples_for "invalid api token" do
    it "errors if no api_token is provided" do
      send request_type, action, params.merge(format: :json)
      expect(response.status).to eql(401)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"Invalid project API TOKEN"}]}})
    end

    it "errors if wrong api_token is provided" do
      send request_type, action, params.merge(format: :json, api_token: "fake")
      expect(response.status).to eql(401)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"Invalid project API TOKEN"}]}})
    end
  end

  describe "#index" do
    it_behaves_like "invalid api token" do
      let(:request_type) { :get }
      let(:action) { :index }
      let(:params) { {} }
    end

    it "retrieves all KeyGroups in the project, but not the KeyGroups in other projects" do
      KeyGroup.delete_all

      project = FactoryGirl.create(:project, repository_url: nil)
      key_group1 = FactoryGirl.create(:key_group, project: project)
      key_group2 = FactoryGirl.create(:key_group, project: project)
      key_group2.update! ready: true

      2.times { FactoryGirl.create(:key_group) }

      get :index, api_token: project.api_token, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql([{"key"=>key_group2.key, "ready"=>true}, {"key"=>key_group1.key, "ready"=>false}])
    end
  end

  describe "#create" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }

    before :each do
      KeyGroup.delete_all
    end

    it_behaves_like "invalid api token" do
      let(:request_type) { :post }
      let(:action) { :create }
      let(:params) { {} }
    end

    it "doesn't create a KeyGroup without a key or source_copy, show the errors to user" do
      post :create, api_token: project.api_token, format: :json
      expect(response.status).to eql(400)
      expect(KeyGroup.count).to eql(0)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"key_sha"=>["is not a valid SHA2 digest"], "source_copy_sha"=>["is not a valid SHA2 digest"], "key"=>["can’t be blank"], "key_sha_raw"=>["can’t be blank"], "source_copy"=>["can’t be blank"], "source_copy_sha_raw"=>["can’t be blank"]}}})
    end

    it "creates a KeyGroup, inherits locale settings from Project" do
      post :create, api_token: project.api_token, key: "test key", source_copy: "<p>a</p><p>b</p>", format: :json
      expect(response.status).to eql(202)
      expect(KeyGroup.count).to eql(1)
      key_group = KeyGroup.last
      expect(key_group.key).to eql("test key")
      expect(key_group.source_copy).to eql("<p>a</p><p>b</p>")
      expect(key_group.keys.count).to eql(2)
      expect(key_group.translations.count).to eql(6)
      expect(key_group.base_rfc5646_locale).to be_nil
      expect(key_group.targeted_rfc5646_locales).to be_nil
      expect(key_group.base_locale).to eql(Locale.from_rfc5646('en'))
      expect(key_group.targeted_locales.map(&:rfc5646).sort).to eql(%w(es fr).sort)
    end

    it "creates a KeyGroup, has its own locale settings different from those of Project's" do
      post :create, api_token: project.api_token, key: "test key", source_copy: "<p>a</p><p>b</p>", base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: { 'ja' => true }, format: :json
      expect(response.status).to eql(202)
      expect(KeyGroup.count).to eql(1)
      key_group = KeyGroup.last
      expect(key_group.keys.count).to eql(2)
      expect(key_group.translations.count).to eql(4)
      expect(key_group.base_rfc5646_locale).to eql('en-US')
      expect(key_group.targeted_rfc5646_locales).to eql({ 'ja' => true })
      expect(key_group.base_locale).to eql(Locale.from_rfc5646('en-US'))
      expect(key_group.targeted_locales.map(&:rfc5646)).to eql(%w(ja))
    end

    it "doesn't create a KeyGroup in a Project with a duplicate key name" do
      FactoryGirl.create(:key_group, project: project, key: "test key", source_copy: "original source copy")
      post :create, api_token: project.api_token, key: "test key", source_copy: "test source copy", format: :json
      expect(response.status).to eql(400)
      expect(KeyGroup.count).to eql(1)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"key_sha_raw"=>["already taken"]}}})
    end
  end

  describe "#show" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
    let(:key_group) { FactoryGirl.create(:key_group, project: project, key: "test", source_copy: "<p>a</p><p>b</p>") }

    it_behaves_like "invalid api token" do
      let(:request_type) { :get }
      let(:action) { :show }
      let(:params) { { key: key_group.key } }
    end

    it "shows details of a KeyGroup" do
      get :show, api_token: project.api_token, key: key_group.key, format: :json

      expect(response.status).to eql(200)
      response_json = JSON.parse(response.body)
      expect(response_json["source_copy"]).to eql("<p>a</p><p>b</p>")
    end
  end

  describe "#update" do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      @key_group = FactoryGirl.create(:key_group, project: @project, key: "test", source_copy: "<p>a</p><p>b</p>")
      @key_group.reload
    end

    it_behaves_like "invalid api token" do
      let(:request_type) { :patch }
      let(:action) { :update }
      let(:params) { { key: @key_group.key } }
    end

    it "updates a KeyGroup" do
      patch :update, api_token: @project.api_token, key: @key_group.key, source_copy: "<p>a</p><p>x</p><p>b</p>", format: :json
      expect(response.status).to eql(202)
      expect(KeyGroup.first.keys.count).to eql(3)
      expect(KeyGroup.first.translations.count).to eql(9)
    end

    it "can update targeted_rfc5646_locales" do
      patch :update, api_token: @project.api_token, key: @key_group.key, targeted_rfc5646_locales: { 'fr' => true }, format: :json
      expect(response.status).to eql(202)
      expect(KeyGroup.count).to eql(1)
      expect(@key_group.reload.targeted_rfc5646_locales).to eql({ 'fr' => true })
    end

    it "can update source_copy without updating targeted_rfc5646_locales" do
      @key_group.update! targeted_rfc5646_locales: { 'fr' => true }
      patch :update, api_token: @project.api_token, key: @key_group.key, source_copy: "<p>a</p><p>x</p><p>b</p>", format: :json
      expect(response.status).to eql(202)
      expect(KeyGroup.count).to eql(1)
      expect(@key_group.reload.targeted_rfc5646_locales).to eql({ 'fr' => true })
      expect(@key_group.source_copy).to eql("<p>a</p><p>x</p><p>b</p>")
    end

    it "errors if source copy is attempted to be updated before the first import didn't finish yet" do
      @key_group.update! last_import_requested_at: 1.minute.ago, last_import_finished_at: nil
      patch :update, api_token: @project.api_token, key: @key_group.key, source_copy: "<p>a</p><p>x</p><p>b</p>", format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"base"=>["latest requested import is not yet finished"]}}})
    end

    it "errors if source copy is attempted to be updated before a subsequent import didn't finish yet" do
      @key_group.update! last_import_requested_at: 1.hour.ago, last_import_finished_at: 2.hours.ago
      patch :update, api_token: @project.api_token, key: @key_group.key, source_copy: "<p>a</p><p>x</p><p>b</p>", format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"base"=>["latest requested import is not yet finished"]}}})
    end

    it "allows updating non-import related fields such as emails and description even if the previous import didn't finish yet" do
      @key_group.update! last_import_requested_at: 1.hour.ago, last_import_finished_at: 2.hours.ago, email: "test@example.com", description: "test"
      expect(@key_group.email).to eql("test@example.com")
      expect(@key_group.description).to eql("test")
      patch :update, api_token: @project.api_token, key: @key_group.key, email: "test2@example.com", description: "test 2", format: :json
      expect(response.status).to eql(202)
      expect(@key_group.reload.email).to eql("test2@example.com")
      expect(@key_group.description).to eql("test 2")
    end

    it "errors if update fails" do
      patch :update, api_token: @project.api_token, key: @key_group.key, source_copy: nil, email: "fake", targeted_rfc5646_locales: {'asdaf-sdfsfs-adas'=> nil}, format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>{"source_copy_sha"=>["is not a valid SHA2 digest"], "source_copy"=>["can’t be blank"], "source_copy_sha_raw"=>["can’t be blank"], "email"=>["invalid"], "targeted_rfc5646_locales"=>["invalid"]}}})
    end
  end

  describe "#status" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
    let(:key_group) { FactoryGirl.create(:key_group, project: project, key: "test", source_copy: "<p>a</p><p>b</p>") }

    it_behaves_like "invalid api token" do
      let(:request_type) { :get }
      let(:action) { :status }
      let(:params) { { key: key_group.key } }
    end

    it "shows status of a KeyGroup" do
      get :status, api_token: project.api_token, key: key_group.key, format: :json

      expect(response.status).to eql(200)
      response_json = JSON.parse(response.body)
      expect(response_json["ready"]).to be_false
    end
  end

  describe "#manifest" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true, 'ja' => true, 'es' => false } ) }
    let(:key_group) { FactoryGirl.create(:key_group, project: project, key: "test", source_copy: "<p>a</p><p>b</p>") }

    it_behaves_like "invalid api token" do
      let(:request_type) { :get }
      let(:action) { :manifest }
      let(:params) { { key: key_group.key } }
    end

    it "errors if not all required locales are ready (i.e. translated)" do
      get :manifest, api_token: project.api_token, key: key_group.key, format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"#<Exporter::KeyGroup::NotReadyError: Exporter::KeyGroup::NotReadyError>"}]}})
    end

    it "downloads the manifest of a KeyGroup" do
      key_group.translations.in_locale(*key_group.required_locales).each do |translation|
        translation.update! copy: "<p>translated</p>", approved: true
      end
      get :manifest, api_token: project.api_token, key: key_group.key, format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql({"fr"=>"<p>translated</p><p>translated</p>", "ja"=>"<p>translated</p><p>translated</p>"})
    end
  end

  describe "#params_for_create" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil) }

    it "permits key, source_copy, description, email, base_rfc5646_locale targeted_rfc5646_locales; but not id or project_id fields" do
      post :create, api_token: project.api_token, key: "t", source_copy: "t", description: "t", email: "t@example.com", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true }, id: 300, project_id: 4, format: :json
      expect(controller.send :params_for_create).to eql({"key"=>"t", "source_copy"=>"t", "description"=>"t", "email"=>"t@example.com", "base_rfc5646_locale"=>"en", "targeted_rfc5646_locales"=>{"fr"=>true}})
    end

    it "doesn't include targeted_rfc5646_locales in the permitted params (this is tested separately because it's a special case due to being a hash field)" do
      post :create, api_token: project.api_token, key: "t", format: :json
      expect(controller.send :params_for_create).to eql({"key"=>"t"})
    end
  end

  describe "#params_for_update" do
    let(:project) { FactoryGirl.create(:project, repository_url: nil) }
    let(:key_group) { FactoryGirl.create(:key_group, project: project, key: "t") }

    it "permits source_copy, description, email, targeted_rfc5646_locales; but not id, project_id, key or base_rfc5646_locale fields" do
      patch :update, api_token: project.api_token, key: key_group.key, source_copy: "t", description: "t", email: "t@example.com", base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true }, id: 300, project_id: 4, format: :json
      expect(controller.send :params_for_update).to eql({"source_copy"=>"t", "description"=>"t", "email"=>"t@example.com", "targeted_rfc5646_locales"=>{"fr"=>true}})
    end

    it "doesn't include targeted_rfc5646_locales in the permitted params (this is tested separately because it's a special case due to being a hash field)" do
      patch :update, api_token: project.api_token, key: key_group.key, source_copy: "t", format: :json
      expect(controller.send :params_for_update).to eql({"source_copy"=>"t"})
    end
  end

  context "[INTEGRATION TESTS]" do
    # This is a real life example. sample_article__original.html was copied and pasted from the help center's website. it was shortened to make tests faster
    it "handles creation, update, update, status, manifest, status, manifest requests in that order" do
      KeyGroup.delete_all
      project = FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true } )

      # Create
      post :create, api_token: project.api_token, key: "support-article", source_copy: File.read(Rails.root.join('spec', 'fixtures', 'key_group_files', 'sample_article__original.html')), format: :json
      expect(response.status).to eql(202)
      expect(KeyGroup.count).to eql(1)
      key_group = KeyGroup.first
      original_key_group_ids = key_group.keys.map(&:id)
      expect(key_group.keys.count).to eql(61)
      expect(key_group.active_keys.count).to eql(61)
      expect(key_group.translations.count).to eql(122)

      # Update: change targeted_rfc5646_locales. previously this defaulted to project settings, this time, put it into the KeyGroup
      patch :update, api_token: project.api_token, key: "support-article", targeted_rfc5646_locales: { 'fr' => true, 'es' => false }, format: :json
      expect(response.status).to eql(202)
      updated_key_group_ids = key_group.reload.keys.map(&:id)
      expect(key_group.keys.count).to eql(61)
      expect((updated_key_group_ids - original_key_group_ids).length).to eql(0) # to make sure that we reused the old keys
      expect(key_group.active_keys.count).to eql(61)
      expect(key_group.translations.count).to eql(183)

      # Update
      # this source copy has 1 changed word, 2 added divs one of which is a duplicate of an existing div, and 1 removed div
      patch :update, api_token: project.api_token, key: "support-article", source_copy: File.read(Rails.root.join('spec', 'fixtures', 'key_group_files', 'sample_article__updated.html')), format: :json
      expect(response.status).to eql(202)
      updated_key_group_ids = key_group.reload.keys.map(&:id)
      expect(key_group.keys.count).to eql(64) # +3 comes from => 2 (addition) + 1 (change)
      expect((updated_key_group_ids - original_key_group_ids).length).to eql(3) # just to make sure that we reused the old keys
      expect(key_group.active_keys.count).to eql(62) # +1 comes from => 2 (addition) - 1 (removal)
      expect(key_group.translations.count).to eql(192)

      # Status
      get :status, api_token: project.api_token, key: "support-article", format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)["ready"]).to be_false

      # Manifest
      get :manifest, api_token: project.api_token, key: "support-article", format: :json
      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to eql({"error"=>{"errors"=>[{"message"=>"#<Exporter::KeyGroup::NotReadyError: Exporter::KeyGroup::NotReadyError>"}]}})

      # Assume all translations are done now
      key_group.reload.translations.where(approved: nil).each do |translation|
        translation.update! copy: "test", approved: true
      end

      # Status
      get :status, api_token: project.api_token, key: "support-article", format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)["ready"]).to be_true

      # Manifest
      get :manifest, api_token: project.api_token, key: "support-article", format: :json
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eql({"fr"=>"test"*62})
    end
  end
end
