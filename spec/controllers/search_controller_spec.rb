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
    before :each do
      reset_elastic_search

      update_date = DateTime.new(2014, 1, 1)
      @user = FactoryGirl.create(:user, :confirmed, role: 'translator')
      @start_date = (update_date - 1.day).strftime('%m/%d/%Y')
      @end_date = (update_date + 1.day).strftime('%m/%d/%Y')

      %w(term1 term2).each do |term|
        %w(source_copy copy).each do |field|
          other_field        = (field == 'copy' ? 'source_copy' : 'copy')
          locale_field       = (field == 'copy' ? :rfc5646_locale : :source_rfc5646_locale)
          other_locale_field = (field == 'copy' ? :source_rfc5646_locale : :rfc5646_locale)
          %w(en ja-JP).each do |locale|
            other_locale = (locale == 'en' ? 'ja-JP' : 'en')
            FactoryGirl.create :translation,
                               field              => "foo #{term} bar",
                               other_field        => 'something else',
                               locale_field       => locale,
                               other_locale_field => other_locale,
                               :updated_at        => update_date,
                               :translator        => @user
          end
        end
      end

      regenerate_elastic_search_indexes

      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep(1)
    end

    it "should filter by page" do
      (1..50).each do
        FactoryGirl.create(:translation)
      end
      sleep(1)
      get :translations, page: '2'
      results = assigns(:results)
      expect(results.size).to eql(8)
    end

    it "should search the copy field by default" do
      get :translations, query: 'term1'
      results = assigns(:results)
      expect(results.size).to eql(2)
      results.each { |r| expect(r.copy).to eql('foo term1 bar') }
    end
    #
    it "should search the source_copy field" do
      get :translations, query: 'term1', field: 'searchable_source_copy'
      results = assigns(:results)
      expect(results.size).to eql(2)
      results.each { |r| expect(r.source_copy).to eql('foo term1 bar') }
    end

    it "should filter by target locale" do
      get :translations, query: 'term1', target_locales: 'ja-JP'
      results = assigns(:results)
      expect(results.size).to eql(1)
      expect(results.first.copy).to eql('foo term1 bar')
      expect(results.first.locale.rfc5646).to eql('ja-JP')
    end

    it "should filter by more than one target locale" do
      get :translations, query: 'term1', target_locales: 'ja-JP, en'
      results = assigns(:results).entries
      # Ensure ordering since ElasticSearch does not guarantee ordering
      results.sort_by! { |r| r.locale.rfc5646 }
      expect(results.first.copy).to eql('foo term1 bar')
      expect(results.first.locale.rfc5646).to eql('en')
      expect(results.last.copy).to eql('foo term1 bar')
      expect(results.last.locale.rfc5646).to eql('ja-JP')
    end

    it "should filter by translator" do
      get :translations, translator_id: @user.id
      results = assigns(:results)
      expect(results.size).to eql(8)

      get :translations, translator_id: @user.id + 1
      results = assigns(:results)
      expect(results.size).to eql(0)
    end

    it "should filter by start date" do
      get :translations, start_date: @start_date
      results = assigns(:results)
      expect(results.size).to eql(8)

      get :translations, start_date: @end_date
      results = assigns(:results)
      expect(results.size).to eql(0)
    end

    it "should filter by end date" do
      get :translations, end_date: @end_date
      results = assigns(:results)
      expect(results.size).to eql(8)

      get :translations, end_date: @start_date
      results = assigns(:results)
      expect(results.size).to eql(0)
    end

    it "should respond with a 422 if the locale is unknown" do
      user = FactoryGirl.create(:user, :confirmed, role: 'translator')
      sign_in user
      get :translations, query: 'term1', target_locales: 'ja-JP, foobar?'
      expect(response.status).to eql(422)
    end
  end

  describe '#keys' do
    before :each do
      reset_elastic_search
      @user    = FactoryGirl.create(:user, :confirmed, role: 'translator')
      @project = FactoryGirl.create(:project)

      5.times { |i| FactoryGirl.create :key, project: @project, key: "t1_n#{i}" }
      5.times { |i| FactoryGirl.create :key, project: @project, key: "t2_n#{i}" }
      regenerate_elastic_search_indexes

      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep(2)
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
      prefix + rand(16**(40 - prefix.length)).to_s(16)
    end

    let(:prefix1) { "abcdef" }
    let(:prefix2) { "123456" }
    let(:prefix3) { "abc111" }

    before :each do
      reset_elastic_search

      @user     = FactoryGirl.create(:user, :confirmed, role: "translator")
      @project1 = FactoryGirl.create(:project)
      @project2 = FactoryGirl.create(:project)
      Commit.delete_all
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
      get :commits, project_id: @project1.id, format: 'json'
      expect(response.status).to eq(200)
      results = JSON.parse(response.body)
      expect(results.size).to eq(5)
    end
  end
end
