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

describe User do
  let(:role) { nil }
  let :user do
    user = FactoryGirl.create(:user, role: role)
    user.approved_rfc5646_locales = %w(en fr)
    user
  end

  context 'an admin user' do
    let(:role) {'admin'}
    it '#has_access_to_locale?() returns true if the user is an admin' do
      expect(user.has_access_to_locale?('fr')).to be_true
      expect(user.has_access_to_locale?('jp')).to be_true
    end
  end
  context 'a translator' do
    let(:role) {'translator'}
    it '#has_access_to_locale?() returns true for non-admins only if they have access to that locale' do
      expect(user.has_access_to_locale?('fr')).to be_true
      expect(user.has_access_to_locale?('jp')).to be_false
    end
  end

  context 'unauthorized user' do
    let(:role) { nil }
    it 'authorizes user when role is no longer nil' do
      expect(user.confirmed_at).to be_nil
      user.update_attribute(:role, 'monitor')
      expect(user.confirmed_at).to_not be_nil
    end
  end

  describe '#after_confirmation' do
    it "sets user's role to monitor if their email address' domain is a privileged domain name" do
      user = FactoryGirl.create(:user, role: nil, email: "test@mycompany.com")
      expect(user.role).to be_nil
      user.after_confirmation
      expect(user.role).to eql('monitor')
    end

    it "doesn't change user's role if priviliged domains are present but their email address' domain is NOT one of them" do
      user = FactoryGirl.create(:user, role: nil, email: "test@example.com")
      expect(user.role).to be_nil
      user.after_confirmation
      expect(user.role).to be_nil
    end

    it "doesn't change user's role if priviliged domains are blank" do
      Shuttle::Configuration.stub(:app).and_return({ })
      user = FactoryGirl.create(:user, role: nil, email: "test@example.com")
      expect(user.role).to be_nil
      user.after_confirmation
      expect(user.role).to be_nil
    end
  end

  describe '#email_domain' do
    it "returns 'example.com' for email address 'test@example.com'" do
      user = FactoryGirl.create(:user, email: "test@example.com")
      expect(user.email_domain).to eql('example.com')
    end
  end

  context '[Integration Tests]' do
    it "sets user's role to monitor after a successful confirmation if their email address' domain is a privileged domain name" do
      user = FactoryGirl.create(:user, role: nil, email: "test@mycompany.com")
      user.send :generate_confirmation_token!
      User.confirm_by_token(user.instance_eval { @raw_confirmation_token } )
      expect(user.reload.role).to eql('monitor')
    end

    it "doesn't change user's role after a successful confirmation if their email address' domain is NOT a privileged domain name" do
      user = FactoryGirl.create(:user, role: nil, email: "test@example.com")
      user.send :generate_confirmation_token!
      User.confirm_by_token(user.instance_eval { @raw_confirmation_token} )
      expect(user.reload.role).to be_nil
    end

    it "doesn't change user's role after an unsuccessful confirmation attempt" do
      user = FactoryGirl.create(:user, role: nil, email: "test@mycompany.com")
      user.send :generate_confirmation_token!
      User.confirm_by_token( "fake" )
      expect(user.reload.role).to be_nil
    end
  end
end
