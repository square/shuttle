# encoding: utf-8

# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the 'License');
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an 'AS IS' BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'rails_helper'

RSpec.describe API::V1::GroupsController do
  let(:project) { FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
  let(:monitor_user) { FactoryBot.create(:user, :confirmed, role: 'monitor') }
  let(:reviewer_user) { FactoryBot.create(:user, :confirmed, role: 'reviewer') }
  let!(:article1) { FactoryBot.create(:article, project: project) }
  let!(:article2) { FactoryBot.create(:article, project: project) }
  let!(:article3) { FactoryBot.create(:article, project: project) }
  let!(:group1) { FactoryBot.create(:group, name: 'group-1', display_name: 'this is group one', project: project) }
  let!(:group2) { FactoryBot.create(:group, name: 'group-2', display_name: 'this is gropu two', project: project) }

  before do
    article2.update(ready: true)
  end

  def sign_in_monitor_user
    request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in monitor_user
  end

  def sign_in_reviewer_user
    request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in reviewer_user
  end

  RSpec.shared_examples_for 'api-or-session-authenticateable-and-filters' do
    context '[auth with api_token]' do
      it 'errors with API error message if wrong api_token is provided' do
        send request_type, action, params.merge(project_id: project.id, format: :json, api_token: 'fake')
        expect(response.status).to eql(401)
        expect(JSON.parse(response.body)).to eql({'error'=>{'errors'=>[{'message'=>'Invalid project API TOKEN'}]}})
      end

      it 'authenticates with api_token' do
        send request_type, action, params.merge(project_id: project.id, format: :json, api_token: project.api_token)
        expect(assigns(:project)).to eq(project) # if @project is set, it means authentication was successful
      end
    end

    context '[auth without api_token]' do
      it 'errors with non-API error message if there is no signed in user' do
        send request_type, action, params.merge(project_id: project.id, format: :json)
        expect(response.status).to eql(401)
        expect(JSON.parse(response.body)).to eql({'error'=>'You need to sign in or sign up before continuing.'})
      end

      it 'authenticates with session if there is a signed in user' do
        sign_in_monitor_user
        send request_type, action, params.merge(project_id: project.id, format: :json)
        expect(assigns(:project)).to eq(project) # if @project is set, it means authentication was successful
      end
    end

    it 'errors with project-not-found message if project_id is invalid (only makes sense with session-auth; because for API-auth, it would error with invalid-token-api message)' do
      sign_in_monitor_user
      send request_type, action, params.merge(project_id: -1, format: :json)
      expect(assigns(:project)).to be_nil
      expect(JSON.parse(response.body)).to eql({'error'=>{'errors'=>[{'message'=>'Invalid project'}]}})
    end
  end

  describe '#index' do
    it_behaves_like 'api-or-session-authenticateable-and-filters', runs_find_group_filter: false do
      let(:request_type) { :get }
      let(:action) { :index }
      let(:params) { {} }
    end

    it 'returns all Groups in the project' do
      get :index, project_id: project.id, api_token: project.api_token, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to match_array(['group-1', 'group-2'])
    end
  end

  describe '#create' do
    it_behaves_like 'api-or-session-authenticateable-and-filters', runs_find_group_filter: false do
      let(:request_type) { :post }
      let(:action) { :create }
      let(:params) { { group: { name: 'dummy-group', display_name: 'this is a dummy group', article_names: [] } } }
    end

    it 'creates a Group' do
      article_names = [article2.name, article1.name, article3.name]
      post :create, project_id: project.id, api_token: project.api_token, group: { name: 'test-group', display_name: 'this is a test group', article_names: article_names, description: 'hello' }, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eq({
        'name' => 'test-group',
        'description' => 'hello',
        'display_name' => 'this is a test group',
        'articles' => [
          { 'name' => article2.name, 'ready' => true },
          { 'name' => article1.name, 'ready' => false },
          { 'name' => article3.name, 'ready' => false }
        ]
      })

      groups = project.groups.where(name: 'test-group')
      expect(groups.count).to eq(1)
      expect(groups.first.display_name).to eq('this is a test group')
      expect(groups.first.articles).to match_array([article2, article1, article3])
      expect(groups.first.description).to eq('hello')
    end

    it 'fails when project has same group name' do
      post :create, project_id: project.id, api_token: project.api_token,  group: { name: group1.name, article_names: [article1.name] }, format: :json

      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>[{'message'=>'Group already exists'}]}})
    end

    it 'succeeds when other project has same group name' do
      other_project = FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      FactoryBot.create(:group, name: 'test-group', project: other_project)

      article_names = [article2.name, article1.name, article3.name]
      post :create, project_id: project.id, api_token: project.api_token, group: { name: 'test-group', article_names: article_names }, format: :json

      expect(response.status).to eql(200)
    end

    it 'fails when articles do not exist' do
      article_names = [article1.name, 'dummy-article-1', 'dummy-article-2']
      post :create, project_id: project.id, api_token: project.api_token,  group: { name:'test-group', article_names: article_names }, format: :json

      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>['Article dummy-article-1 does not exist', 'Article dummy-article-2 does not exist']}})
    end

    it 'fails when other project has the article' do
      other_project = FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      other_article = FactoryBot.create(:article, name: 'other-article', project: other_project)

      article_names = [other_article.name]
      post :create, project_id: project.id, api_token: project.api_token,  group: { name:'test-group', article_names: article_names }, format: :json

      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>['Article other-article does not exist']}})
    end
  end

  describe '#show' do
    before do
      FactoryBot.create(:article_group, article: article1, group: group1, index_in_group: 1)
      FactoryBot.create(:article_group, article: article3, group: group1, index_in_group: 0)
    end

    it_behaves_like 'api-or-session-authenticateable-and-filters' do
      let(:request_type) { :get }
      let(:action) { :show }
      let(:params) { { name: group1.name } }
    end

    it 'returns articles in the group' do
      get :show, project_id: project.id, api_token: project.api_token, name: group1.name, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eq({
        'name' => group1.name,
        'description' => group1.description,
        'display_name' => group1.display_name,
        'articles' => [
          { 'name' => article3.name, 'ready' => false },
          { 'name' => article1.name, 'ready' => false }
        ]
      })
    end

    it 'fails when group does not exist' do
      get :show, project_id: project.id, api_token: project.api_token, name: 'dummy-artcile-group', format: :json

      expect(response.status).to eql(404)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>[{'message'=>'Group does not exist'}]}})
    end
  end

  describe '#update' do
    before do
      FactoryBot.create(:article_group, article: article1, group: group1, index_in_group: 1)
      FactoryBot.create(:article_group, article: article3, group: group1, index_in_group: 0)
    end

    it_behaves_like 'api-or-session-authenticateable-and-filters' do
      let(:request_type) { :patch }
      let(:action) { :update }
      let(:params) { { name: group1.name, group: { article_names: [] } } }
    end

    it 'updates articles in the group' do
      expect(project.groups.find_by_name(group1.name).articles).to match_array([article1, article3])

      article_names = [article2.name, article3.name]
      patch :update, project_id: project.id, api_token: project.api_token, name: group1.name, group: { article_names: article_names, description: 'hello', display_name: 'this is updated group' }, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eq({
        'name' => group1.name,
        'description' => 'hello',
        'display_name' => 'this is updated group',
        'articles' => [
          { 'name' => article2.name, 'ready' => true },
          { 'name' => article3.name, 'ready' => false }
        ]
      })

      group = project.groups.find_by_name(group1.name)
      expect(group.articles).to match_array([article2, article3])
      expect(group.description).to eq('hello')
      expect(group.display_name).to eq('this is updated group')
    end

    it 'fails when group does not exist' do
      patch :update, project_id: project.id, api_token: project.api_token, name: 'dummy-article-group', group: { article_names: [] }, format: :json

      expect(response.status).to eql(404)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>[{'message'=>'Group does not exist'}]}})
    end

    it 'fails when articles do not exist' do
      article_names = [article1.name, 'dummy-article-1', 'dummy-article-2']
      patch :update, project_id: project.id, api_token: project.api_token, name: group1.name, group: { article_names: article_names }, format: :json

      expect(response.status).to eql(400)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>['Article dummy-article-1 does not exist', 'Article dummy-article-2 does not exist']}})
    end
  end

  describe '#destroy' do
    before do
      FactoryBot.create(:article_group, article: article1, group: group1, index_in_group: 1)
      FactoryBot.create(:article_group, article: article3, group: group1, index_in_group: 0)
    end

    it_behaves_like 'api-or-session-authenticateable-and-filters' do
      let(:request_type) { :delete }
      let(:action) { :destroy }
      let(:params) { { name: group1.name } }
    end

    it 'deletes articles in the group' do
      delete :destroy, project_id: project.id, api_token: project.api_token, name: group1.name, format: :json

      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).to eq({ "status" => true })

      expect(project.groups.where(name: group1.name).count).to eq(0)
    end

    it 'fails when group does not exist' do
      delete :destroy, project_id: project.id, api_token: project.api_token, name: 'dummy-article-group', format: :json

      expect(response.status).to eql(404)
      expect(JSON.parse(response.body)).to match_array({'error'=>{'errors'=>[{'message'=>'Group does not exist'}]}})
    end
  end
end
