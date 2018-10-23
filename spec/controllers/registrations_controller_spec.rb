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

RSpec.describe 'registration', type: :request do
  let(:params) { { user: user} }
  let(:url) { nil }
  let(:extra_params) { nil }
  subject { post url, params, extra_params }

  describe '#create' do
    let(:url) { 'http://test.host/users' }
    let(:user) do
      {
        email:                 email,
        first_name:            'Sancho',
        last_name:             'Sample',
        password:              'test123',
        password_confirmation: 'test123'
      }
    end

    context 'with proper email' do
      let(:email) { 'foo@example.com' }
      let(:extra_params) { { 'REMOTE_ADDR' => '101.0.0.1' } }

      it 'should require email confirmation' do
        ActionMailer::Base.deliveries.clear

        response = subject
        expect(response).to eq(302)

        user = User.last
        expect(user.email).to eql('foo@example.com')
        expect(user.confirmed_at).to be_nil
        expect(ActionMailer::Base.deliveries.count).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to eql("[Shuttle] Confirmation instructions")
      end
    end

    context 'with bogus email' do
      let(:email) { 'foo123' }
      let(:extra_params) { { 'REMOTE_ADDR' => '101.0.0.2' } }

      it 'should handle bogus email addresses' do
        response = subject
        expect(response).to eq(200)

        expect(User.count).to be_zero
      end
    end

    context 'throttling requests' do
      let(:email) { 'foo@example.com' }
      let(:extra_params) { { 'REMOTE_ADDR' => '101.0.0.3' } }

      it 'fails after 20 tries' do
        20.times.each do |index|
          params[:user][:email] = "foo-#{index}@example.com"
          response = post(url, params, extra_params)
          expect(response).to eq(302)
        end
        expect(User.count).to eq(20)

        params[:user][:email] = "foo-21@example.com"
        response = post(url, params, extra_params)
        expect(response).to eq(503)
        expect(User.count).to eq(20)

        # success with other IP
        response = post(url, params, { 'REMOTE_ADDR' => '101.0.1.3' })
        expect(response).to eq(302)
      end
    end
  end

  describe '#sign_in' do
    let(:url) { 'http://test.host/users/sign_in' }
    let(:email) { 'foo@example.com' }
    let(:password) { 'test123'}
    let(:user) do
      {
        email:    email,
        password: password,
      }
    end

    before do
      login_params = {
        user: {
          email:                 email,
          first_name:            'Sancho',
          last_name:             'Sample',
          password:              password,
          password_confirmation: password
        }
      }
      post 'http://test.host/users', login_params
    end

    context 'with proper credential' do
      let(:extra_params) { { 'REMOTE_ADDR' => '102.0.0.1' } }

      it 'logged in successfully' do
        response = subject
        expect(response).to eq(302)
      end
    end

    context 'with invalid credential' do
      let(:email) { 'foo123' }
      let(:extra_params) { { 'REMOTE_ADDR' => '102.0.0.2' } }

      it 'failed to login' do
        response = subject
        expect(response).to eq(200)
      end
    end

    context 'throttling requests' do
      let(:extra_params) { { 'REMOTE_ADDR' => '102.0.0.3' } }

      it 'fails after 20 tries' do
        20.times.each do |index|
          params[:user][:email] = "foo-#{index}@example.com"
          response = post(url, params, extra_params)
          expect(response).to eq(200)
        end

        params[:user][:email] = "foo-21@example.com"
        response = post(url, params, extra_params)
        expect(response).to eq(503)

        # success with other IP
        response = post(url, params, { 'REMOTE_ADDR' => '102.0.1.3' })
        expect(response).to eq(200)
      end
    end
  end

  describe '#unlock' do
    let(:url) { 'http://test.host/users/unlock' }
    let(:email) { 'foo@example.com' }
    let(:user) do
      {
        email:    email,
      }
    end

    context 'throttling requests' do
      let(:extra_params) { { 'REMOTE_ADDR' => '103.0.0.3' } }

      it 'fails after 20 tries' do
        20.times.each do |index|
          params[:user][:email] = "foo-#{index}@example.com"
          response = post(url, params, extra_params)
          expect(response).to eq(200)
        end

        params[:user][:email] = "foo-21@example.com"
        response = post(url, params, extra_params)
        expect(response).to eq(503)

        # success with other IP
        response = post(url, params, { 'REMOTE_ADDR' => '103.0.1.3' })
        expect(response).to eq(200)
      end
    end
  end
end
