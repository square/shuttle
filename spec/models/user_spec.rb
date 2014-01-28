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
  context "an admin user" do
    let(:role) {'admin'}
    it "#has_access_to_locale?() returns true if the user is an admin" do
      expect(user.has_access_to_locale?('fr')).to be_true
      expect(user.has_access_to_locale?('jp')).to be_true
    end
  end
  context "a translator" do
    let(:role) {'translator'}
    it "#has_access_to_locale?() returns true for non-admins only if they have access to that locale" do
      expect(user.has_access_to_locale?('fr')).to be_true
      expect(user.has_access_to_locale?('jp')).to be_false
    end
  end
end

