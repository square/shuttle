require 'spec_helper'

describe 'Authentication' do
  include ActionView::Helpers

  after(:all) do
    Capybara.use_default_driver
  end

  context '[reset password]' do
    before(:all) do
      User.delete_all
      @user = FactoryGirl.create(:user)
    end

    before(:each) do
      ActionMailer::Base.deliveries.clear
      Capybara.current_driver = :webkit
    end

    after(:each) do
      Capybara.reset!
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
      expect(email.subject).to eql('Reset password instructions')
    end
  end

end