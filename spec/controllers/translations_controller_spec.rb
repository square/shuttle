# Copyright 2013 Square Inc.
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
      @project     = FactoryGirl.create(:project, repository_url: 'git://github.com/RISCfuture/better_caller.git')
      @key         = FactoryGirl.create(:key, project: @project)
      @translation = FactoryGirl.create(:translation, copy: 'some copy here', key: @key)
      @user        = FactoryGirl.create(:user, role: 'monitor')
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should return information about a translation" do
      get :show, project_id: @project.to_param, key_id: @key.to_param, id: @translation.to_param, format: 'json'
      response.status.should eql(200)
      JSON.parse(response.body)['copy'].should eql('some copy here')
    end
  end

  describe "#update" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'translator')
    end

    before :each do
      @translation                   = FactoryGirl.create(:translation, copy: nil, translated: false, approved: nil)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should update the translation and set the translator" do
      put :update,
          project_id:  @translation.key.project.to_param,
          key_id:      @translation.key.to_param,
          id:          @translation.to_param,
          translation: {copy: 'hello!'},
          format:      'json'
      response.status.should eql(200)
      @translation.reload.copy.should eql('hello!')
      @translation.should be_translated
      @translation.translator.should eql(@user)
    end

    context "[empty copy]" do
      it "should clear and de-translate a translation if given empty copy" do
        @translation.copy       = 'hello!'
        @translation.translator = @user
        @translation.save!

        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: ''},
            format:      'json'
        response.status.should eql(200)
        @translation.reload.copy.should be_nil
        @translation.should_not be_translated
        @translation.approved.should be_nil
        @translation.translator.should be_nil
        @translation.reviewer.should be_nil
      end

      it "should update the translation normally if given empty copy and blank_string=true" do
        @translation.copy = 'hello!'
        @translation.save!

        put :update,
            project_id:   @translation.key.project.to_param,
            key_id:       @translation.key.to_param,
            id:           @translation.to_param,
            translation:  {copy: ''},
            blank_string: '1',
            format:       'json'
        response.status.should eql(200)
        @translation.reload.copy.should eql('')
        @translation.should be_translated
        @translation.translator.should eql(@user)
      end
    end

    context "[reviewer changes]" do
      before(:all) { @user = FactoryGirl.create(:user, role: 'reviewer') }

      it "should automatically approve reviewer changes to an approved string" do
        @translation.copy       = 'hello!'
        @translation.translator = translator = FactoryGirl.create(:user, role: 'translator')
        @translation.approved   = true
        @translation.save!

        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: 'bye!'},
            format:      'json'

        response.status.should eql(200)
        @translation.reload.copy.should eql('bye!')
        @translation.should be_approved
        @translation.translator.should eql(@user)
        @translation.reviewer.should eql(@user)
      end

      it "should automatically approve reviewer changes to an untranslated string" do
        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: 'bye!'},
            format:      'json'

        response.status.should eql(200)
        @translation.reload.copy.should eql('bye!')
        @translation.should be_approved
        @translation.translator.should eql(@user)
        @translation.reviewer.should eql(@user)
      end

      it "should automatically approve reviewer non-changes to a translated string" do
        @translation.copy       = 'hello!'
        @translation.translator = translator = FactoryGirl.create(:user, role: 'translator')
        @translation.save!

        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: 'hello!'},
            format:      'json'

        response.status.should eql(200)
        @translation.reload.copy.should eql('hello!')
        @translation.should be_approved
        @translation.translator.should eql(translator)
        @translation.reviewer.should eql(@user)
      end
    end

    context "[permissions]" do
      it "should not allow a translator to update approved copy" do
        @user.update_attribute :role, 'translator'
        @translation.copy     = 'foo'
        @translation.approved = true
        @translation.save!

        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: 'bar'},
            format:      'json'

        response.status.should eql(403)
        @translation.reload.copy.should eql('foo')
        @translation.should be_approved
      end

      it "should allow a reviewer to update approved copy" do
        @user.update_attribute :role, 'reviewer'
        @translation.copy     = 'foo'
        @translation.approved = true
        @translation.save!

        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: 'bar'},
            format:      'json'

        response.status.should eql(200)
        @translation.reload.copy.should eql('bar')
        @translation.should be_approved
      end

      it "should allow an admin to update approved copy" do
        @user.update_attribute :role, 'admin'
        @translation.copy     = 'foo'
        @translation.approved = true
        @translation.save!

        put :update,
            project_id:  @translation.key.project.to_param,
            key_id:      @translation.key.to_param,
            id:          @translation.to_param,
            translation: {copy: 'bar'},
            format:      'json'

        response.status.should eql(200)
        @translation.reload.copy.should eql('bar')
        @translation.should be_approved
      end
    end
  end

  describe "#approve" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'reviewer')
    end

    before :each do
      @translation                   = FactoryGirl.create(:translation, copy: 'hello!', translated: true, approved: nil)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should approve the translation and set the reviewer" do
      put :approve,
          project_id: @translation.key.project.to_param,
          key_id:     @translation.key.to_param,
          id:         @translation.to_param

      @translation.reload.approved.should eql(true)
      @translation.reviewer.should eql(@user)
    end
  end

  describe "#reject" do
    before :all do
      @user = FactoryGirl.create(:user, role: 'reviewer')
    end

    before :each do
      @translation                   = FactoryGirl.create(:translation, copy: 'hello!', translated: true, approved: nil)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should reject the translation and set the reviewer" do
      put :reject,
          project_id: @translation.key.project.to_param,
          key_id:     @translation.key.to_param,
          id:         @translation.to_param

      @translation.reload.approved.should eql(false)
      @translation.reviewer.should eql(@user)
    end
  end

  describe "#match" do
    before :all do
      @project = FactoryGirl.create(:project)
      @user    = FactoryGirl.create(:user, role: 'reviewer')
    end

    before :each do
      Locale.any_instance.stub(:fallbacks).and_return(
          %w(fr-CA fr en).map { |l| Locale.from_rfc5646 l }
      )

      hello_123  = FactoryGirl.create(:key, project: @project, key: 'hello_123')
      anotherkey = FactoryGirl.create(:key, project: @project, key: 'anotherkey')

      @original_translation = FactoryGirl.create(:translation,
                                                 source_copy:    'hello123',
                                                 key:            hello_123,
                                                 rfc5646_locale: 'fr-CA',
                                                 copy:           nil,
                                                 translated:     false,
                                                 approved:       nil)
      @same_locale_sc       = FactoryGirl.create(:translation,
                                                 source_copy:    'hello123',
                                                 key:            anotherkey,
                                                 rfc5646_locale: 'fr-CA',
                                                 copy:           'same_locale_sc',
                                                 translated:     true,
                                                 approved:       true)
      @fallback1_sc         = FactoryGirl.create(:translation,
                                                 source_copy:    'hello123',
                                                 key:            anotherkey,
                                                 rfc5646_locale: 'fr',
                                                 copy:           'fallback1_sc',
                                                 translated:     true,
                                                 approved:       true)
      @fallback2_sc         = FactoryGirl.create(:translation,
                                                 source_copy:    'hello123',
                                                 key:            anotherkey,
                                                 rfc5646_locale: 'en',
                                                 copy:           'fallback2_sc',
                                                 translated:     true,
                                                 approved:       true)

      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should 1. respond with a translation with matching locale and source copy" do
      get :match,
          project_id: @project.to_param,
          key_id:     @original_translation.key.to_param,
          id:         @original_translation.to_param,
          format:     'json'
      response.status.should eql(200)
      JSON.parse(response.body)['copy'].should eql('same_locale_sc')
    end

    it "should 2. respond with a translation of the 1st fallback locale with matching project/key and source copy" do
      TranslationUnit.exact_matches(@same_locale_sc).delete_all
      get :match,
          project_id: @project.to_param,
          key_id:     @original_translation.key.to_param,
          id:         @original_translation.to_param,
          format:     'json'
      response.status.should eql(200)
      JSON.parse(response.body)['copy'].should eql('fallback1_sc')
    end

    it "should 3. respond with a translation of the 1st fallback locale with source copy" do
      TranslationUnit.exact_matches(@same_locale_sc).delete_all
      TranslationUnit.exact_matches(@fallback1_sc).delete_all
      get :match,
          project_id: @project.to_param,
          key_id:     @original_translation.key.to_param,
          id:         @original_translation.to_param,
          format:     'json'
      response.status.should eql(200)
      JSON.parse(response.body)['copy'].should eql('fallback2_sc')
    end

    it "should 6. respond with a 204" do
      TranslationUnit.exact_matches(@same_locale_sc).delete_all
      TranslationUnit.exact_matches(@fallback1_sc).delete_all
      TranslationUnit.exact_matches(@fallback2_sc).delete_all
      get :match,
          project_id: @project.to_param,
          key_id:     @original_translation.key.to_param,
          id:         @original_translation.to_param,
          format:     'json'
      response.status.should eql(204)
      response.body.should be_blank
    end
  end
end
