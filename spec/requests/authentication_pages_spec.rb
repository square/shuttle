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

describe 'Authentication', capybara: true do
  include ActionView::Helpers

  before :each do
    Capybara.reset!
    Capybara.current_driver = :webkit
    ActionMailer::Base.deliveries.clear
  end

  after :all do
    Capybara.use_default_driver
  end

  context '[signup]' do
    it 'lets you access the Sign Up page' do
      visit new_user_session_path
      expect(page).to have_content 'Log in to Shuttle'
      page.find(:link, 'Sign up').click
      expect(page).to have_content 'Sign up for Shuttle'
    end

    it 'lets you register a non-square account but doesn\'t send confirmation e-mail' do
      non_square_user = FactoryGirl.build(:user)

      visit new_user_session_path + '#sign-up'
      expect(page).to have_content 'Sign up for Shuttle'

      fill_in 'user[first_name]', with: non_square_user.first_name
      fill_in 'user[last_name]', with: non_square_user.last_name
      fill_in 'user[email]', with: non_square_user.email
      fill_in 'user[password]', with: non_square_user.password
      fill_in 'user[password_confirmation]', with: non_square_user.password

      click_button 'Sign up'

      expect(current_path).to eql(new_user_session_path)
      expect(page).to have_css '.flash-shown'
      expect(page).to have_content t('devise.registrations.signed_up_but_inactive')

      expect(ActionMailer::Base.deliveries.size).to eql(0)
    end

    it 'lets you register a square account and sends confirmation e-mail' do
      square_user = FactoryGirl.build(:user, email: 'test@example.com')

      visit new_user_session_path + '#sign-up'
      expect(page).to have_content 'Sign up for Shuttle'

      fill_in 'user[first_name]', with: square_user.first_name
      fill_in 'user[last_name]', with: square_user.last_name
      fill_in 'user[email]', with: square_user.email
      fill_in 'user[password]', with: square_user.password
      fill_in 'user[password_confirmation]', with: square_user.password

      click_button 'Sign up'

      expect(current_path).to eql(new_user_session_path)
      expect(page).to have_css '.flash-shown'
      expect(page).to have_content t('devise.registrations.signed_up_but_unconfirmed')

      expect(ActionMailer::Base.deliveries.size).to eql(1)
      email = ActionMailer::Base.deliveries.first
      expect(email.subject).to eql('[Shuttle] Confirmation instructions')
    end
  end

  context '[reset password]' do
    before :each do
      @user = FactoryGirl.create(:user)
    end

    it 'lets you access the Forgot Password page' do
      visit new_user_session_path
      expect(page).to have_content 'Log in to Shuttle'
      page.find(:link, 'Forgot Password?').click
      expect(page).to have_content 'Forgot your password?'
    end

    it 'sends an email to the user when their password is forgotten' do
      visit new_user_session_path + '#forgot-password'
      expect(page).to have_content 'Forgot your password?'

      fill_in 'user[email]', with: @user.email
      click_button 'Send E-mail'

      expect(current_path).to eql(new_user_session_path)
      expect(page).to have_css '.flash-shown'
      expect(page).to have_content t('devise.passwords.send_instructions')

      expect(ActionMailer::Base.deliveries.size).to eql(1)

      email = ActionMailer::Base.deliveries.first
      expect(email.subject).to eql('[Shuttle] Reset password instructions')
    end
  end

end
