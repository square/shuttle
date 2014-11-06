# encoding: utf-8

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

describe SubstitutionController do
  describe '#convert' do
    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in FactoryGirl.create(:user, :activated)
    end

    it "should 404 if the from locale is invalid" do
      get :convert, from: 'wut is this', to: 'en-CA', string: 'What a colorful catalog.', format: 'json'
      expect(response.status).to eql(404)
      expect(response.body).to be_blank
    end

    it "should 404 if the to locale is invalid" do
      get :convert, from: 'en-US', to: 'hello there', string: 'What a colorful catalog.', format: 'json'
      expect(response.status).to eql(404)
      expect(response.body).to be_blank
    end

    it "should 400 if the string is not given" do
      get :convert, from: 'en-US', to: 'en-CA', format: 'json'
      expect(response.status).to eql(400)
      expect(response.body).to be_blank
    end

    it "should 400 if the string is invalid" do
      get :convert, from: 'en-US', to: 'en-CA', string: {'hello' => 'world'}, format: 'json'
      expect(response.status).to eql(400)
      expect(response.body).to be_blank
    end

    it "should 422 if the from and to locales are not convertible" do
      get :convert, from: 'en-US', to: 'fr-CA', string: 'What a colorful catalog.', format: 'json'
      expect(response.status).to eql(422)
      expect(response.body).to be_blank
    end

    it "should return the JSON-formatted result object of the conversion" do
      get :convert, from: 'en-US', to: 'en-CA', string: 'What a colorful catalog.', format: 'json'
      expect(response.status).to eql(200)
      expect(JSON.parse(response.body)).
          to eql(
                     'string'      => 'What a colourful catalog.',
                     'suggestions' => [{
                                           'range'      => [17, 23],
                                           'replacement' => 'catalogue, calendar',
                                           'note'       => "use “catalogue” when referring to a product brochure, and “calendar” when referring to a university course listing"
                                       }],
                     'notes'       => []
                 )
    end
  end
end
