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

describe ScreenshotsController do
  let(:monitor)         { FactoryGirl.create(:user, :confirmed, role: 'monitor') }
  let(:translator)      { FactoryGirl.create(:user, :confirmed, role: 'translator') }
  let(:reviewer)        { FactoryGirl.create(:user, :confirmed, role: 'reviewer') }
  let(:commit)          { FactoryGirl.create(:commit) }
  let(:screenshot)      { FactoryGirl.attributes_for :screenshot }
  let(:bad_screenshot)  { FactoryGirl.attributes_for :screenshot, image: File.new(Rails.root.join('spec', 'fixtures', 'test.txt')) }

  describe 'POST #create' do
    context 'is a monitor' do
      before :each do
        sign_in monitor
      end

      it 'should save the new screenshot' do
        post :create, project_id: commit.project.to_param, commit_id: commit.to_param, screenshot: screenshot, format: 'json'
        expect(Screenshot.count).to eql(1)
      end

      it 'should respond with status OK if successful' do
        post :create, project_id: commit.project.to_param, commit_id: commit.to_param, screenshot: screenshot, format: 'json'
        expect(response.status).to eql(200)
      end

      it 'should respond with status BAD_REQUEST if unsuccessful' do
        post :create, project_id: commit.project.to_param, commit_id: commit.to_param, screenshot: bad_screenshot, format: 'json'
        expect(response.status).to eql(422)
      end
    end

    context 'is a translator' do
      before :each do
        sign_in translator
      end

      it 'should not be able to create a screenshot' do
        post :create, project_id: commit.project.to_param, commit_id: commit.to_param, screenshot: screenshot, format: 'json'
        expect(response.status).to eql(403)
      end
    end
  end

  describe 'POST #request_screenshots' do
    before :each do
      ActionMailer::Base.deliveries = []
    end

    context 'not signed in' do
      it 'should 401 if user is not signed in' do
        post :request_screenshots, project_id: commit.project.to_param, commit_id: commit.to_param, format: 'json'
        expect(response.status).to eql(401)
        expect(ActionMailer::Base.deliveries.count).to eql(0)
      end
    end

    context 'is signed in' do
      it 'send an email to request a screenshot' do
        sign_in translator
        post :request_screenshots, project_id: commit.project.to_param, commit_id: commit.to_param, format: 'json'
        expect(response.status).to eql(200)
        expect(ActionMailer::Base.deliveries.count).to eql(1)
      end
    end
  end
end
