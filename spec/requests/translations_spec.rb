require 'rails_helper'

RSpec.describe "Translations", type: :request do
  describe "#update" do
    before(:each) do
      user = FactoryBot.create(:user, :activated, :confirmed, :translator)
      # this only works if you post AND call the sign_in helper (in that order), not sure why
      post_via_redirect user_session_path, 'user[email]' => user.email, 'user[password]' => user.password
      sign_in user
    end

    it 'handles a commit in the params' do
      project = FactoryBot.create(:project, targeted_rfc5646_locales: {'fr'=>true, 'es'=>true}, base_rfc5646_locale: 'en')
      key1 = FactoryBot.create(:key, key: "firstkey",  project: project)
      translation = FactoryBot.create(:translation, source_rfc5646_locale: 'en', source_copy: 'fake', copy: nil, approved: nil, key: key1)
      commit = '12345678901234567890'
      url = project_key_translation_path(project, key1, translation.to_param, commit: commit)
      patch_via_redirect url, translation: { copy: 'fake' }

      expect(response).to render_template(:edit)
      expect(translation.reload.copy).to eq 'fake'
      expect(TranslationChange.first.sha).to eq commit
    end

    it 'handles a project in the params' do
      project = FactoryBot.create(:project, targeted_rfc5646_locales: {'fr'=>true, 'es'=>true}, base_rfc5646_locale: 'en')
      key1 = FactoryBot.create(:key, key: "firstkey",  project: project)
      translation = FactoryBot.create(:translation, source_rfc5646_locale: 'en', source_copy: 'fake', copy: nil, approved: nil, key: key1)
      url = project_key_translation_path(project, key1, translation.to_param)
      patch_via_redirect url, translation: { copy: 'fake' }

      expect(TranslationChange.first.project_id).to eq project.id
    end

    it 'only inserts a single translation change record' do
      project = FactoryBot.create(:project, targeted_rfc5646_locales: {'fr'=>true, 'es'=>true}, base_rfc5646_locale: 'en')
      key1 = FactoryBot.create(:key, key: "firstkey",  project: project)
      translation = FactoryBot.create(:translation, source_rfc5646_locale: 'en', source_copy: 'fake', copy: nil, approved: nil, key: key1)
      url = project_key_translation_path(project, key1, translation.to_param)
      expect{ patch_via_redirect url, translation: { copy: 'fake' } }.to change{ TranslationChange.count }.by(1) 
    end
  end
end
