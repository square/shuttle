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

describe RegistrationsController do
  before(:each) { @request.env["devise.mapping"] = Devise.mappings[:user] }

  describe '#create' do
    it "should require email confirmation" do
      ActionMailer::Base.deliveries.clear
      post :create, user: {
          email:                 'foo@example.com',
          first_name:            'Sancho',
          last_name:             'Sample',
          password:              'test123',
          password_confirmation: 'test123'
      }
      user = User.last
      expect(user.email).to eql('foo@example.com')
      expect(user.confirmed_at).to be_nil
      expect(ActionMailer::Base.deliveries.count).to eql(1)
      expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Confirmation instructions")
    end

    it "should handle bogus email addresses" do
      post :create, user: {
          email:                 'foo123',
          first_name:            'Sancho',
          last_name:             'Sample',
          password:              'test123',
          password_confirmation: 'test123'
      }
      expect(User.count).to be_zero
    end
  end
end
