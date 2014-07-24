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

describe TranslationsController do
  include Devise::TestHelpers

  describe "#show" do
    before :all do
      Project.delete_all
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @key = FactoryGirl.create(:key, project: @project)
      @translation = FactoryGirl.create(:translation, copy: 'some copy here', key: @key)
      @user = FactoryGirl.create(:user, role: 'monitor')
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should return information about a translation" do
      get :show, project_id: @project.to_param, key_id: @key.to_param, id: @translation.to_param, format: 'json'
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)['copy']).to eql('some copy here')
    end
  end

  describe "#update" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'translator')
    end

    before :each do
      @translation = FactoryGirl.create(:translation, copy: nil, translated: false, approved: nil)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should update the translation and set the translator" do
      patch :update,
            project_id: @translation.key.project.to_param,
            key_id: @translation.key.to_param,
            id: @translation.to_param,
            translation: { copy: 'hello!' },
            format: 'json'
      expect(response.status).to eql(200)
      expect(@translation.reload.copy).to eql('hello!')
      expect(@translation).to be_translated
      expect(@translation.translator).to eql(@user)

      expect(@translation.translation_changes.count).to eq(1)
      change = @translation.translation_changes.first
      expect(change.translation).to eq(@translation)
      expect(change.diff).to eq({ "copy" => [nil, 'hello!'] })
      expect(change.user).to eq(@user)
    end

    context "[empty copy]" do
      it "should clear and de-translate a translation if given empty copy" do
        @translation.copy = 'hello!'
        @translation.translator = @user
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: '' },
              format: 'json'
        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to be_nil
        expect(@translation).not_to be_translated
        expect(@translation.approved).to be_nil
        expect(@translation.translator).to be_nil
        expect(@translation.reviewer).to be_nil

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last.reload
        expect(change.translation).to eq(@translation)
        expect(change.diff).to eq({ "copy" => ['hello!', nil] })
        expect(change.user).to eq(@user)
      end

      it "should update the translation normally if given empty copy and blank_string=true" do
        @translation.copy = 'hello!'
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: '' },
              blank_string: '1',
              format: 'json'
        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to eql('')
        expect(@translation).to be_translated
        expect(@translation.translator).to eql(@user)

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last
        expect(change.translation).to eq(@translation)
        expect(change.diff).to eq({ "copy" => ['hello!', ''] })
        expect(change.user).to eq(@user)
      end
    end

    context "[reviewer changes]" do
      before(:all) { @user = FactoryGirl.create(:user, role: 'reviewer') }

      it "should automatically approve reviewer changes to an approved string" do
        @translation.copy = 'hello!'
        @translation.translator = translator = FactoryGirl.create(:user, role: 'translator')
        @translation.approved = true
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: 'bye!' },
              format: 'json'

        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to eql('bye!')
        expect(@translation).to be_approved
        expect(@translation.translator).to eql(@user)
        expect(@translation.reviewer).to eql(@user)

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last
        expect(change.translation).to eq(@translation)
        expect(change.diff).to eq({ "copy" => ['hello!', 'bye!'] })
        expect(change.user).to eq(@user)
      end

      it "should automatically approve reviewer changes to an untranslated string" do
        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: 'bye!' },
              format: 'json'

        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to eql('bye!')
        expect(@translation).to be_approved
        expect(@translation.translator).to eql(@user)
        expect(@translation.reviewer).to eql(@user)

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last
        expect(change.translation).to eq(@translation)
        expect(change.diff).to eq({ "copy" => [nil, 'bye!'], "approved" => [nil, true] })
        expect(change.user).to eq(@user)
      end

      it "should automatically approve reviewer non-changes to a translated string" do
        @translation.copy = 'hello!'
        @translation.translator = translator = FactoryGirl.create(:user, role: 'translator')
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: 'hello!' },
              format: 'json'

        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to eql('hello!')
        expect(@translation).to be_approved
        expect(@translation.translator).to eql(translator)
        expect(@translation.reviewer).to eql(@user)

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last
        expect(change.diff).to eq({ "approved" => [nil, true] })
        expect(change.user).to eq(@user)
      end
    end

    context "[permissions]" do
      it "should not allow a translator to update approved copy" do
        @user.update_attribute :role, 'translator'
        @translation.copy = 'foo'
        @translation.approved = true
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: 'bar' },
              format: 'json'

        expect(response.status).to eql(403)
        expect(@translation.reload.copy).to eql('foo')
        expect(@translation).to be_approved
        expect(@translation.translation_changes.count).to eq(0)
      end

      it "should allow a reviewer to update approved copy" do
        @user.update_attribute :role, 'reviewer'
        @translation.copy = 'foo'
        @translation.approved = true
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: 'bar' },
              format: 'json'

        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to eql('bar')
        expect(@translation).to be_approved

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last
        expect(change.diff).to eq({ "copy" => ['foo', 'bar'] })
        expect(change.translation).to eq(@translation)
        expect(change.user).to eq(@user)
      end

      it "should allow an admin to update approved copy" do
        @user.update_attribute :role, 'admin'
        @translation.copy = 'foo'
        @translation.approved = true
        @translation.save!
        @translation.translation_changes.delete_all

        patch :update,
              project_id: @translation.key.project.to_param,
              key_id: @translation.key.to_param,
              id: @translation.to_param,
              translation: { copy: 'bar' },
              format: 'json'

        expect(response.status).to eql(200)
        expect(@translation.reload.copy).to eql('bar')
        expect(@translation).to be_approved

        expect(@translation.translation_changes.count).to eq(1)
        change = @translation.translation_changes.last
        expect(change.diff).to eq({ "copy" => ['foo', 'bar'] })
        expect(change.translation).to eq(@translation)
        expect(change.user).to eq(@user)
      end
    end

    context "[unmatched fences]" do
      it "should not update the translation if source_fences and fences don't match" do
        key = FactoryGirl.create(:key, fencers: %w(Mustache Html))
        translation = FactoryGirl.create(:translation, key: key, source_copy: "test {{hello}} <strong>hi</strong> {{how are you}}", copy: nil, translated: false, approved: nil).tap(&:valid?)
        patch :update, project_id: key.project.to_param, key_id: key.to_param, id: translation.to_param, translation: { copy: "test <strong>hi</strong> {{how are you}}" }, format: 'json'

        expect(response.status).to eql(422)
        expect(translation.reload.copy).to eql(nil)
        expect(translation).to_not be_translated
        expect(translation.translation_changes.count).to eq(0)
      end

      it "should not update the translation if source_copy has fences and copy is empty string" do
        key = FactoryGirl.create(:key, fencers: %w(Mustache Html))
        translation = FactoryGirl.create(:translation, key: key, source_copy: "test {{hello}}", copy: nil, translated: false, approved: nil).tap(&:valid?)
        patch :update, project_id: key.project.to_param, key_id: key.to_param, id: translation.to_param, translation: { copy: '' }, format: 'html'

        expect(response.status).to eql(422)
        expect(translation.reload.copy).to eql(nil)
        expect(translation).to_not be_translated
        expect(translation.translation_changes.count).to eq(0)
      end

      it "should update the translation if source_fences and fences counts match" do
        key = FactoryGirl.create(:key, fencers: %w(Mustache Html))
        translation = FactoryGirl.create(:translation, key: key, source_copy: "test {{hello}} <strong> asda </strong> {{a}}", copy: nil, translated: false, approved: nil).tap(&:valid?)
        patch :update, project_id: key.project.to_param, key_id: key.to_param, id: translation.to_param, translation: { copy: "test {{hello}} <strong> asda </strong> {{a}}" }, format: 'json'

        expect(response.status).to eql(200)
        expect(translation.reload.copy).to eql("test {{hello}} <strong> asda </strong> {{a}}")
        expect(translation).to be_translated
        expect(translation.translation_changes.count).to eq(1)
      end
    end
  end

  describe "#approve" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'reviewer')
    end

    before :each do
      @translation = FactoryGirl.create(:translation, copy: 'hello!', translated: true, approved: nil)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should approve the translation and set the reviewer" do
      patch :approve,
            project_id: @translation.key.project.to_param,
            key_id: @translation.key.to_param,
            id: @translation.to_param

      expect(@translation.reload.approved).to eql(true)
      expect(@translation.reviewer).to eql(@user)

      expect(@translation.translation_changes.count).to eq(1)
      change = @translation.translation_changes.last
      expect(change.diff).to eq({ "approved" => [nil, true] })
      expect(change.translation).to eq(@translation)
      expect(change.user).to eq(@user)
    end
  end

  describe "#reject" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'reviewer')
    end

    before :each do
      @translation = FactoryGirl.create(:translation, copy: 'hello!', translated: true, approved: nil)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should reject the translation and set the reviewer" do
      patch :reject,
            project_id: @translation.key.project.to_param,
            key_id: @translation.key.to_param,
            id: @translation.to_param

      expect(@translation.reload.approved).to eql(false)
      expect(@translation.reviewer).to eql(@user)

      expect(@translation.translation_changes.count).to eq(1)
      change = @translation.translation_changes.last
      expect(change.diff).to eq({ "approved" => [nil, false] })
      expect(change.translation).to eq(@translation)
      expect(change.user).to eq(@user)
    end
  end

  describe "#match" do
    before :all do
      @project = FactoryGirl.create(:project)
      @user = FactoryGirl.create(:user, role: 'reviewer')
    end

    before :each do
      allow_any_instance_of(Locale).to receive(:fallbacks).and_return(
                                           %w(fr-CA fr en).map { |l| Locale.from_rfc5646 l }
                                       )

      hello_123 = FactoryGirl.create(:key, project: @project, key: 'hello_123')
      anotherkey = FactoryGirl.create(:key, project: @project, key: 'anotherkey')

      @original_translation = FactoryGirl.create(:translation,
                                                 source_copy: 'hello123',
                                                 key: hello_123,
                                                 rfc5646_locale: 'fr-CA',
                                                 copy: nil,
                                                 translated: false,
                                                 approved: nil)
      @same_locale_sc = FactoryGirl.create(:translation,
                                           source_copy: 'hello123',
                                           key: anotherkey,
                                           rfc5646_locale: 'fr-CA',
                                           copy: 'same_locale_sc',
                                           translated: true,
                                           approved: true)
      @fallback1_sc = FactoryGirl.create(:translation,
                                         source_copy: 'hello123',
                                         key: anotherkey,
                                         rfc5646_locale: 'fr',
                                         copy: 'fallback1_sc',
                                         translated: true,
                                         approved: true)
      @fallback2_sc = FactoryGirl.create(:translation,
                                         source_copy: 'hello123',
                                         key: anotherkey,
                                         rfc5646_locale: 'en',
                                         copy: 'fallback2_sc',
                                         translated: true,
                                         approved: true)

      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should 1. respond with a translation unit with matching locale and source copy" do
      get :match,
          project_id: @project.to_param,
          key_id: @original_translation.key.to_param,
          id: @original_translation.to_param,
          format: 'json'
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)['copy']).to eql('same_locale_sc')
    end

    it "should 2. respond with the newest translation unit with matching locale and source copy (if there are duplicates)" do
      Timecop.freeze(Time.now + 5.hours)

      duplicate_key = FactoryGirl.create(:key,
                                         project: @project,
                                         key: 'duplicate_key')
      FactoryGirl.create(:translation,
                         source_copy: 'hello123',
                         key: duplicate_key,
                         rfc5646_locale: 'fr-CA',
                         copy: 'duplicate_locale_sc',
                         translated: true,
                         approved: true)

      get :match,
          project_id: @project.to_param,
          key_id:     @original_translation.key.to_param,
          id:         @original_translation.to_param,
          format:     'json'
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)['copy']).to eql('duplicate_locale_sc')

      Timecop.return
    end

    it "should 3. respond with the translation unit of the 1st fallback locale with matching project/key and source copy" do
      TranslationUnit.exact_matches(@same_locale_sc).delete_all
      get :match,
          project_id: @project.to_param,
          key_id: @original_translation.key.to_param,
          id: @original_translation.to_param,
          format: 'json'
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)['copy']).to eql('fallback1_sc')
    end

    it "should 4. respond with the translation unit of the 1st fallback locale with source copy" do
      TranslationUnit.exact_matches(@same_locale_sc).delete_all
      TranslationUnit.exact_matches(@fallback1_sc).delete_all
      get :match,
          project_id: @project.to_param,
          key_id: @original_translation.key.to_param,
          id: @original_translation.to_param,
          format: 'json'
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)['copy']).to eql('fallback2_sc')
    end

    it "should 5. respond with a 204" do
      TranslationUnit.exact_matches(@same_locale_sc).delete_all
      TranslationUnit.exact_matches(@fallback1_sc).delete_all
      TranslationUnit.exact_matches(@fallback2_sc).delete_all
      get :match,
          project_id: @project.to_param,
          key_id: @original_translation.key.to_param,
          id: @original_translation.to_param,
          format: 'json'
      expect(response.status).to eql(204)
      expect(response.body).to be_blank
    end
  end

  describe "#fuzzy_match" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'translator')
    end

    before :each do
      Translation.destroy_all

      reset_elastic_search
      @translation = FactoryGirl.create :translation,
                                        source_copy: 'foo bar 1',
                                        copy: 'something else',
                                        source_rfc5646_locale: 'en',
                                        rfc5646_locale: 'fr'

      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should return potential fuzzy matches" do
      FactoryGirl.create :translation,
                         source_copy: 'foo bar 2',
                         copy: 'something else',
                         source_rfc5646_locale: 'en',
                         rfc5646_locale: 'fr'
      regenerate_elastic_search_indexes
      sleep(2)

      get :fuzzy_match,
          project_id: @translation.key.project.to_param,
          key_id: @translation.key.to_param,
          id: @translation.to_param,
          format: 'json'

      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(2)
    end

    it "should not return matches where the copy is nil" do
      FactoryGirl.create :translation,
                         source_copy: 'foo bar 2',
                         copy: nil,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale: 'fr'

      regenerate_elastic_search_indexes
      sleep(2)

      get :fuzzy_match,
          project_id: @translation.key.project.to_param,
          key_id: @translation.key.to_param,
          id: @translation.to_param,
          format: 'json'

      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(1)
    end

    it "should return at most 5 fuzzy matches" do
      (1..10).each do |i|
        FactoryGirl.create :translation,
                           source_copy: "foo bar #{i}",
                           copy: 'something else',
                           source_rfc5646_locale: 'en',
                           rfc5646_locale: 'fr'
      end

      regenerate_elastic_search_indexes
      sleep(2)

      get :fuzzy_match,
          project_id: @translation.key.project.to_param,
          key_id: @translation.key.to_param,
          id: @translation.to_param,
          format: 'json'

      expect(response.status).to eql(200)
      results = JSON.parse(response.body)
      expect(results.size).to eql(5)
    end

    it "should sort fuzzy_matches by match_percentage and ensure greater than 60" do
      (10..50).step(10).each do |i|
        FactoryGirl.create :translation,
                           source_copy: "foo bar #{'a' * i}",
                           copy: 'something else',
                           source_rfc5646_locale: 'en',
                           rfc5646_locale: 'fr'
      end

      regenerate_elastic_search_indexes
      sleep(2)

      get :fuzzy_match,
          project_id: @translation.key.project.to_param,
          key_id: @translation.key.to_param,
          id: @translation.to_param,
          format: 'json'

      expect(response.status).to eql(200)
      sorted_results = JSON.parse(response.body).map { |r| r['match_percentage'] }
      sorted_results.each { |r| expect(r).to be >= 60 }
      expect(sorted_results).to eql(sorted_results.sort.reverse)
    end
  end
end
