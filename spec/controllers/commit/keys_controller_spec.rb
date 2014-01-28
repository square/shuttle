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

describe Commit::KeysController do
  describe '#index' do
    before :all do
      reset_elastic_search

      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    base_rfc5646_locale:      'en',
                                    targeted_rfc5646_locales: {'en' => true, 'fr' => true},
                                    repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)

      @commit       = @project.commit!('HEAD', skip_import: true)
      @keys         = FactoryGirl.create_list(:key, 51, project: @project).sort_by(&:key)
      @translations = @keys.map do |key|
        FactoryGirl.create :translation,
                           key:                   key, rfc5646_locale: 'en',
                           source_rfc5646_locale: 'en',
                           approved:              true,
                           translated:            true
      end.sort_by { |t| t.key.key }
      @keys.each &:add_pending_translations
      @commit.keys = @keys

      @user = FactoryGirl.create(:user, role: 'monitor')

      regenerate_elastic_search_indexes
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep 2
    end

    it "should return the first 50 keys of a commit" do
      get :index, project_id: @project.to_param, commit_id: @commit.to_param, status: 'approved', format: 'json'
      expect(response.status).to eql(200)
      body = JSON.parse(response.body)
      expect(body).to be_kind_of(Array)
      expect(body.size).to eql(50)
      expect(body.map { |k| k['key'] }).to eql(@keys[0, 50].map(&:key))
      expect(body.map { |k| k['translations'].size }).to eql([2]*50)
    end

    it "should accept an offset" do
      get :index, project_id: @project.to_param, commit_id: @commit.to_param, status: 'approved', format: 'json', offset: 50
      expect(response.status).to eql(200)
      body = JSON.parse(response.body)
      expect(body.size).to eql(1)
      expect(body.first['key']).to eql(@keys.last.key)
    end
  end
end
