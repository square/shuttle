# Copyright 2016 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicabcle law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe SearchTranslationsFinder do

  describe "#find_translations" do
    before :each do
      Translation.destroy_all
      reset_elastic_search
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @key = create_key(@project)
      @translation = create_translation(@key, copy: 'some copy here', rfc5646_locale: Locale.new('de-DE').rfc5646)
      @finder = create_finder
    end

    it "should include new translation" do
      regenerate_elastic_search_indexes_helper
      expect(@finder.find_translations.total_count).to eq(1)

      new_key = create_key(@project)
      create_translation(new_key)
      regenerate_elastic_search_indexes_helper
      expect(@finder.find_translations.total_count).to eq(2)
    end

    it "should filter target locales" do
      create_translation(@key)
      new_finder = create_finder(target_locales: [Locale.new('zh-CN'), Locale.new('ja-JP')])
      regenerate_elastic_search_indexes_helper

      expect(@finder.find_translations.total_count).to eq(2)
      expect(new_finder.find_translations.total_count).to eq(1)
    end

    it "should filter project id" do
      new_project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      new_key = create_key(new_project)
      create_translation(new_key)
      new_finder = create_finder(project_id: new_project.id)
      regenerate_elastic_search_indexes_helper

      expect(@finder.find_translations.total_count).to eq(2)
      expect(new_finder.find_translations.total_count).to eq(1)
    end

    it "should filter translation id" do
      new_finder = create_finder(translator_id: 15875)
      regenerate_elastic_search_indexes_helper

      expect(@finder.find_translations.total_count).to eq(1)
      expect(new_finder.find_translations.total_count).to eq(0)
    end

    it "should filter start date" do
      create_translation(@key, updated_at: Time.current - 7.days)
      new_finder = create_finder(start_date: Time.current - 3.days)
      regenerate_elastic_search_indexes_helper

      expect(@finder.find_translations.total_count).to eq(2)
      expect(new_finder.find_translations.total_count).to eq(1)
    end

    it "should filter end date" do
      create_translation(@key, updated_at: Time.current + 7.days)
      new_finder = create_finder(end_date: Time.current + 3.days)
      regenerate_elastic_search_indexes_helper

      expect(@finder.find_translations.total_count).to eq(2)
      expect(new_finder.find_translations.total_count).to eq(1)
    end

    it "should filter hidden keys" do
      hidden_key = create_key(@project, hidden_in_search: true)
      create_translation(hidden_key)
      regenerate_elastic_search_indexes_helper

      expect(@finder.find_translations.total_count).to eq(1)
    end

    it "should only show hidden keys" do
      new_finder = create_finder(hidden_keys: 'true')
      3.times do
        hidden_key = create_key(@project, hidden_in_search: true)
        create_translation(hidden_key)
      end
      regenerate_elastic_search_indexes_helper
      expect(@finder.find_translations.total_count).to eq(1)
      expect(new_finder.find_translations.total_count).to eq(3)
    end
  end

  private

  def regenerate_elastic_search_indexes_helper
    regenerate_elastic_search_indexes
    sleep(2)
  end

  def create_finder(params={})
    form = {
      page: 50
    }.deep_merge(params)

    SearchTranslationsFinder.new(form)
  end

  def create_translation(key, params={})
    data = {
      key: key,
      copy: 'hello food',
      rfc5646_locale: Locale.new('zh-CN').rfc5646
    }.deep_merge(params)

    FactoryGirl.create(:translation, data)
  end

  def create_key(project, params={})
    data = {
      project: project
    }.deep_merge(params)

    FactoryGirl.create(:key, data)
  end
end