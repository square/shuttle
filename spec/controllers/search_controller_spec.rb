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

describe SearchController do
  include Devise::TestHelpers

  describe "#translations" do
    before :all do
      reset_elastic_search
      @user = FactoryGirl.create(:user, role: 'translator')

      %w(term1 term2).each do |term|
        %w(source_copy copy).each do |field|
          other_field = (field == 'copy' ? 'source_copy' : 'copy')
          locale_field = (field == 'copy' ? :rfc5646_locale : :source_rfc5646_locale)
          other_locale_field = (field == 'copy' ? :source_rfc5646_locale : :rfc5646_locale)
          %w(en fr).each do |locale|
            other_locale = (locale == 'en' ? 'fr' : 'en')
            FactoryGirl.create :translation,
                               field => "foo #{term} bar",
                               other_field => 'something else',
                               locale_field => locale,
                               other_locale_field => other_locale
          end
        end
      end

      regenerate_elastic_search_indexes
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep(2)
    end

    it "should search the copy field by default" do
      get :translations, query: 'term1', format: 'json'
      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(2)
      results.each { |r| expect(r['copy']).to eql('foo term1 bar') }
    end

    it "should search the source_copy field" do
      get :translations, query: 'term1', field: 'searchable_source_copy', format: 'json'
      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(2)
      results.each { |r| expect(r['source_copy']).to eql('foo term1 bar') }
    end

    it "should filter by target locale" do
      get :translations, query: 'term1', target_locales: 'fr', format: 'json'
      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(1)
      expect(results.first['copy']).to eql('foo term1 bar')
      expect(results.first['locale']['rfc5646']).to eql('fr')
    end

    it "should filter by more than one target locale" do
      get :translations, query: 'term1', target_locales: 'fr, en', format: 'json'
      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(2)
      expect(results.first['copy']).to eql('foo term1 bar')
      expect(results.first['locale']['rfc5646']).to eql('fr')
      expect(results.last['copy']).to eql('foo term1 bar')
      expect(results.last['locale']['rfc5646']).to eql('en')
    end

    it "should respond with a 422 if the locale is unknown" do
      get :translations, query: 'term1', target_locales: 'fr, foobar?', format: 'json'
      expect(response.status).to eql(422)
      expect(response.body).to be_blank
    end

    it "should accept a limit and offset" do
      get :translations, query: 'term1', offset: 0, limit: 1, format: 'json'
      expect(response.status).to eql(200)
      results1 = JSON.parse(response.body)
      expect(results1.size).to eql(1)

      get :translations, query: 'term1', offset: 1, limit: 1, format: 'json'
      expect(response.status).to eql(200)
      results2 = JSON.parse(response.body)
      expect(results2.size).to eql(1)

      expect(results1.first['id']).not_to eql(results2.first['id'])
    end
  end

  describe '#keys' do
    before :all do
      reset_elastic_search
      @user = FactoryGirl.create(:user, role: 'translator')
      @project = FactoryGirl.create(:project)

      5.times { |i| FactoryGirl.create :key, project: @project, key: "t1_n#{i}" }
      5.times { |i| FactoryGirl.create :key, project: @project, key: "t2_n#{i}"
      regenerate_elastic_search_indexes}
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep(2)
    end

    it "should return an empty result list if no query is given" do
      get :keys, keys: ' ', project_id: @project.id, format: 'json'
      expect(response.status).to eql(200)
      expect(response.body).to eql('[]')
    end

    it "should search by key" do
      get :keys, filter: 't1', project_id: @project.id, format: 'json'
      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(5)
      expect(results.map { |r| r['original_key'] }.sort).to eql(%w(t1_n0 t1_n1 t1_n2 t1_n3 t1_n4))
    end

    it "should respond with a 422 if the project ID is not given" do
      get :keys, filter: 't1', format: 'json'
      expect(response.status).to eql(422)
      expect(response.body).to be_blank
    end

    it "should accept a limit and offset" do
      get :keys, filter: 't1', project_id: @project.id, offset: 0, limit: 1, format: 'json'
      expect(response.status).to eql(200)
      results1 = JSON.parse(response.body)
      expect(results1.size).to eql(1)

      get :keys, filter: 't1', project_id: @project.id, offset: 1, limit: 1, format: 'json'
      expect(response.status).to eql(200)
      results2 = JSON.parse(response.body)
      expect(results2.size).to eql(1)

      expect(results1.first['id']).not_to eql(results2.first['id'])
    end

    context "[?metadata=true]" do
      it "should return search metadata" do
        project = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US', targeted_rfc5646_locales: {'en-US' => true, 'aa' => true, 'ja' => false})
        get :keys, project_id: project.id, metadata: 'true', format: 'json'
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body)).
            to eql('locales' => %w(en-US aa ja).map { |l| Locale.from_rfc5646(l).as_json.recursively(&:stringify_keys!) })
      end

      it "should respond with 404 if the project is not found" do
        get :keys, project_id: Project.maximum(:id) + 1, metadata: 'true', format: 'json'
        expect(response.status).to eql(404)
      end

      it "should respond with 422 if the project is not given" do
        get :keys, metadata: 'true', format: 'json'
        expect(response.status).to eql(422)
      end
    end
  end

  describe "#commits" do
    def finish_sha(prefix="")
      prefix + rand(16**(40 - prefix.length)).to_s(16).rjust(40, '0')
    end

    let(:prefix1) { "abcdef" }
    let(:prefix2) { "123456" }
    let(:prefix3) { "abc111" }

    before :all do
      reset_elastic_search

      @user = FactoryGirl.create(:user, role: "translator")
      @project1 = FactoryGirl.create(:project)
      @project2 = FactoryGirl.create(:project)
      2.times { FactoryGirl.create(:commit, project: @project1, revision: finish_sha("abcdef")) }
      2.times { FactoryGirl.create(:commit, project: @project1, revision: finish_sha("123456")) }
      1.times { FactoryGirl.create(:commit, project: @project1, revision: finish_sha("abc111")) }
      1.times { FactoryGirl.create(:commit, project: @project2, revision: finish_sha("abc111")) }

      regenerate_elastic_search_indexes
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep 2
    end

    it "should return all commits if no filters are given" do
      get :commits, format: 'json'
      expect(response.status).to eq(200)
      results = JSON.parse(response.body)
      expect(results.size).to eq(6)
    end

    it "should return no commits if SHA given doesn't match any commits" do
      get :commits, sha: '321', format: 'json'
      expect(response.status).to eq(200)
      expect(response.body).to eq('[]')
    end

    it "should filter according to SHA prefix" do
      get :commits, sha: 'abc', format: 'json'
      expect(response.status).to eq(200)
      results = JSON.parse(response.body)
      expect(results.size).to eq(4)
    end

    it "should filter according to project_id if given" do
      get :commits, project_id: @project1.id, format:'json'
      expect(response.status).to eq(200)
      results = JSON.parse(response.body)
      expect(results.size).to eq(5)
    end
  end
end
