# Copyright 2016 Square Inc.
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

describe GlossaryController do
  include Devise::TestHelpers

  describe '#index' do
    before :each do
      reset_elastic_search

      update_date = DateTime.new(2014, 1, 1)
      @user = FactoryGirl.create(:user, :confirmed, role: 'translator')
      @start_date = (update_date - 1.day).strftime('%m/%d/%Y')
      @end_date = (update_date + 1.day).strftime('%m/%d/%Y')

      %w(ar cn fr ja).each do |locale|
        FactoryGirl.create :project,
                           repository_url: nil,
                           base_rfc5646_locale: 'en',
                           targeted_rfc5646_locales: { locale => true }
      end

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

    let(:length_of_anchor_list) { 27 }

    it "should have 'en' as its source locale" do
      get :index
      expect(assigns(:source_locale)).to eq('en')
    end

    it 'should have a set of default target locales' do
      get :index
      expect(assigns(:target_locales).map(&:rfc5646))
        .to eq(Shuttle::Configuration.locales.default_filter_locales)
    end

    it 'should switch to multiple non-default locales' do
      get :index, target_locales: 'cn,fr'
      expect(assigns(:target_locales).map(&:rfc5646)).to eq(['cn', 'fr'])
    end

    it 'it should generate an anchor list of length 27' do
      get :index
      expect(assigns(:anchors).length).to eq(length_of_anchor_list)
    end

    let(:words_in_glossary) { %w(1word Aword Bword Zword1 Zword2) }
    let(:expected_anchors) { %w(# A B Z) }

    it 'should group glossary entries in alphabetical order' do
      words_in_glossary.each do |source_copy|
        FactoryGirl.create :source_glossary_entry,
                           source_copy: source_copy
      end

      get :index
      result = assigns(:grouped_source_entries)
      expect(result.length).to eq(4)
      expect(result.keys).to eq(expected_anchors)
      expect(result.values.flatten.map(&:source_copy)).to eq(words_in_glossary)
    end
  end
end
