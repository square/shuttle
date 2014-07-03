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
  before(:all) { User.delete_all }
  before(:each) { @request.env["devise.mapping"] = Devise.mappings[:user] }

  describe '#create' do
    it "should require email confirmation for a Square email address" do
      post :create, user: {
          email:                 'foo@squareup.com',
          first_name:            'Sancho',
          last_name:             'Sample',
          password:              'test123',
          password_confirmation: 'test123'
      }
      user = User.last
      expect(user.email).to eql('foo@squareup.com')
      expect(user.confirmed_at).to be_nil
    end

    it "should otherwise not require email confirmation but create an inactive account" do
      post :create, user: {
          email:                 'foo@bar.com',
          first_name:            'Sancho',
          last_name:             'Sample',
          password:              'test123',
          password_confirmation: 'test123'
      }
      user = User.last
      expect(user.email).to eql('foo@bar.com')
      expect(user.confirmed_at).not_to be_nil
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
