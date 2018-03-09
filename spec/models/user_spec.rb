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

require 'rails_helper'

RSpec.describe User do
  before :each do
    app_config = Shuttle::Configuration.automatic_user_privileges
    allow(Shuttle::Configuration).to receive(:automatic_user_privileges).
        and_return(app_config.merge(domains_to_get_monitor_role_after_email_confirmation: ['example.com'],
                                    domains_who_can_search_users:                         ['example.com']))
  end

  let(:role) { nil }
  let :user do
    FactoryBot.create(:user, role: role).tap do |user|
      user.approved_rfc5646_locales = %w(en fr en-CA fr-ca)
    end
  end

  context "[scopes]" do
    describe "#has_role" do
      it "returns monitors and translators, doesn't return users with role=nil" do
        monitor = FactoryBot.create(:user, role: 'monitor')
        translator = FactoryBot.create(:user, role: 'translator')
        other = FactoryBot.create(:user, role: nil)
        expect(User.has_role.to_a).to match_array([monitor, translator])
      end
    end

    describe "#confirmed" do
      it "returns confirmed users" do
        confirmed = FactoryBot.create(:user, :confirmed)
        not_confirmed = FactoryBot.create(:user)
        expect(User.confirmed.to_a).to eql([confirmed])
      end
    end

    describe "#activated" do
      it "returns activated users" do
        activated = FactoryBot.create(:user, :activated)
        not_with_role = FactoryBot.create(:user, :confirmed)
        not_confirmed = FactoryBot.create(:user)
        expect(User.activated.to_a).to eql([activated])
      end
    end
  end

  context 'an admin user' do
    let(:role) {'admin'}
    it '#has_access_to_locale?() returns true if the user is an admin' do
      expect(user.has_access_to_locale?('fr')).to be_truthy
      expect(user.has_access_to_locale?('jp')).to be_truthy
    end
  end
  context 'a translator' do
    let(:role) {'translator'}

    context '#has_access_to_locale?()' do
      it 'returns true for non-admins only if they have access to that locale' do
        expect(user.has_access_to_locale?('fr')).to be_truthy
        expect(user.has_access_to_locale?('jp')).to be_falsey
      end

      it "is case-insensitive if argument is a string" do
        expect(user.has_access_to_locale?('en-ca')).to be_truthy
        expect(user.has_access_to_locale?('en-CA')).to be_truthy
        expect(user.has_access_to_locale?('fr-ca')).to be_truthy
        expect(user.has_access_to_locale?('fr-CA')).to be_truthy
      end
    end
  end

  context 'unauthorized user' do
    let(:role) { nil }
    it "doesn't confirm user when a role is assigned to the user" do
      expect(user.confirmed_at).to be_nil
      user.update!(role: 'monitor')
      expect(user.confirmed_at).to be_nil
    end
  end

  describe '#after_confirmation' do
    it "sets user's role to monitor if their email address' domain is a privileged domain name" do
      user = FactoryBot.create(:user, role: nil, email: "test@example.com")
      expect(user.role).to be_nil
      user.after_confirmation
      expect(user.role).to eql('monitor')
    end

    it "doesn't change user's role if priviliged domains are present but their email address' domain is NOT one of them" do
      user = FactoryBot.create(:user, role: nil, email: "test@notpriviliged.com")
      expect(user.role).to be_nil
      user.after_confirmation
      expect(user.role).to be_nil
    end

    it "doesn't change user's role if priviliged domains are blank" do
      allow(Shuttle::Configuration).to receive(:app).and_return({ })
      user = FactoryBot.create(:user, role: nil, email: "test@example.com")
      expect(user.role).to be_nil
      user.after_confirmation
      expect(user.role).to be_nil
    end
  end

  describe '#activated?' do
    it "returns true if user has a role and is confirmed" do
      expect(FactoryBot.create(:user, :activated).activated?).to be_truthy
    end

    it "returns false if user doesn't have a role, even if the user is confirmed" do
      expect(FactoryBot.create(:user, :confirmed).activated?).to be_falsey
    end

    it "returns false if user is not confirmed even if the user has a role" do
      user = FactoryBot.create(:user, role: 'monitor')
      expect(user.activated?).to be_falsey
    end
  end

  describe '#has_role?' do
    it "returns true if user's role is set" do
      expect(FactoryBot.create(:user, role: 'monitor').has_role?).to be_truthy
    end

    it "returns false if user's role is not set" do
      expect(FactoryBot.create(:user, role: nil).has_role?).to be_falsey
    end
  end

  describe '#email_domain' do
    it "returns 'example.com' for email address 'test@example.com'" do
      user = FactoryBot.create(:user, email: "test@example.com")
      expect(user.email_domain).to eql('example.com')
    end
  end

  describe '#can_search_users?' do
    it "returns true if user's email domain allows for searching" do
      user = FactoryBot.create(:user, :activated, email: "test@example.com")
      expect(user.can_search_users?).to be_truthy
    end

    it "returns false if user's email domain doesn't allow for searching" do
      user = FactoryBot.create(:user, :activated, email: "test@notallowed.com")
      expect(user.can_search_users?).to be_falsey
    end
  end

  context '[Integration Tests]' do
    it "sets user's role to monitor after a successful confirmation if their email address' domain is a privileged domain name" do
      user = FactoryBot.create(:user, role: nil, email: "test@example.com")
      user.send :generate_confirmation_token!
      User.confirm_by_token(user.instance_eval { @raw_confirmation_token } )
      expect(user.reload.role).to eql('monitor')
    end

    it "doesn't change user's role after a successful confirmation if their email address' domain is NOT a privileged domain name" do
      user = FactoryBot.create(:user, role: nil, email: "test@notpriviliged.com")
      user.send :generate_confirmation_token!
      User.confirm_by_token(user.instance_eval { @raw_confirmation_token} )
      expect(user.reload.role).to be_nil
    end

    it "doesn't change user's role after an unsuccessful confirmation attempt" do
      user = FactoryBot.create(:user, role: nil, email: "test@example.com")
      user.send :generate_confirmation_token!
      User.confirm_by_token( "fake" )
      expect(user.reload.role).to be_nil
    end
  end
end
