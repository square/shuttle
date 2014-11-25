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

describe UsersController do
  describe "#search" do
    subject { get :search, { query: "test", format: :json } }

    before :each do
      Shuttle::Configuration.stub(:app).and_return(domains_to_get_monitor_role_after_email_confirmation: ['example.com'], domains_who_can_search_users: ['example.com'])

      @request.env['devise.mapping'] = Devise.mappings[:user]
      @activated_and_priviliged_user = FactoryGirl.create(:user, :activated, email: "someuser@example.com")
    end

    context "[disabled cases]" do
      it "redirects if there is no signed in user" do
        subject
        expect(JSON.parse(response.body)).to eql({"error"=>"You need to sign in or sign up before continuing."})
      end

      it "returns nothing if current_user is not confirmed" do
        sign_in FactoryGirl.create(:user, role: 'monitor', email: "test@example.com") # not confirmed, has role, priviliged domain
        subject
        expect(JSON.parse(response.body)).to eql({"error"=>"You have to confirm your account before continuing."})
      end

      it "returns nothing if current_user doesn't have a role" do
        sign_in FactoryGirl.create(:user, :confirmed, email: "test@example.com") # confirmed, doesn't have role, priviliged domain
        subject
        expect(JSON.parse(response.body)).to eql({"error"=>"Your account was not activated yet."})
      end

      it "returns nothing if current_user's domain is not whitelisted in the privileged domains" do
        sign_in FactoryGirl.create(:user, :confirmed, role: 'monitor', email: "test@notprivileged.com") # confirmed, has role, not priviliged domain
        subject
        expect(response.body).to be_blank
      end
    end

    context "[enabled cases]" do
      before :each do
        sign_in @activated_and_priviliged_user
      end

      context "[matching by email address]" do
        it "returns matched users' email addresses and names" do
          FactoryGirl.create(:user, :activated, first_name: "first",  last_name: "user1", email: 'test@example.com')    # start
          FactoryGirl.create(:user, :activated, first_name: "second", last_name: "user2", email: '1test@example.com')   # middle
          FactoryGirl.create(:user, :activated, first_name: "third",  last_name: "user3", email: 'test2@example.com')   # start
          FactoryGirl.create(:user, :activated, first_name: "forth",  last_name: "user4", email: 'hello@example.test')  # end
          FactoryGirl.create(:user, :activated, first_name: "fifth",  last_name: "user5", email: 'nomatch@example.com') # not a match
          subject
          expect(JSON.parse(response.body)).to match_array([{"name"=>"first user1", "email"=>"test@example.com"},
                                                            {"name"=>"second user2", "email"=>"1test@example.com"},
                                                            {"name"=>"third user3", "email"=>"test2@example.com"},
                                                            {"name"=>"forth user4", "email"=>"hello@example.test"}])
        end

        it "returns exact matched users' email addresses and names" do
          FactoryGirl.create(:user, :activated, first_name: "first",  last_name: "user1", email: 'test@example.com') # exact
          get :search, { query: "test@example.com", format: :json }
          expect(JSON.parse(response.body)).to eql([{"name"=>"first user1", "email"=>"test@example.com"}])
        end
      end

      context "[matching by first name]" do
        it "returns matched users' email addresses and names" do
          FactoryGirl.create(:user, :activated, first_name: "test",   last_name: "user1", email: 'user1@example.com') # exact
          FactoryGirl.create(:user, :activated, first_name: "1test",  last_name: "user2", email: 'user2@example.com') # end
          FactoryGirl.create(:user, :activated, first_name: "test2",  last_name: "user3", email: 'user3@example.com') # start
          FactoryGirl.create(:user, :activated, first_name: "1test2", last_name: "user4", email: 'user4@example.com') # middle
          FactoryGirl.create(:user, :activated, first_name: "user",   last_name: "user5", email: 'user5@example.com') # miss
          subject
          expect(JSON.parse(response.body)).to match_array([{"name"=>"test user1",   "email"=>"user1@example.com"},
                                                            {"name"=>"1test user2",  "email"=>"user2@example.com"},
                                                            {"name"=>"test2 user3",  "email"=>"user3@example.com"},
                                                            {"name"=>"1test2 user4", "email"=>"user4@example.com"}])
        end
      end

      context "[matching by last name]" do
        it "returns matched users' email addresses and names" do
          FactoryGirl.create(:user, :activated, first_name: "user1", last_name: "test",   email: 'user1@example.com') # exact
          FactoryGirl.create(:user, :activated, first_name: "user2", last_name: "1test",  email: 'user2@example.com') # end
          FactoryGirl.create(:user, :activated, first_name: "user3", last_name: "test2",  email: 'user3@example.com') # start
          FactoryGirl.create(:user, :activated, first_name: "user4", last_name: "1test2", email: 'user4@example.com') # middle
          FactoryGirl.create(:user, :activated, first_name: "user5", last_name: "user",   email: 'user5@example.com') # miss
          subject
          expect(JSON.parse(response.body)).to match_array([{"name"=>"user1 test",   "email"=>"user1@example.com"},
                                                            {"name"=>"user2 1test",  "email"=>"user2@example.com"},
                                                            {"name"=>"user3 test2",  "email"=>"user3@example.com"},
                                                            {"name"=>"user4 1test2", "email"=>"user4@example.com"}])
          end
      end


      it "returns results matched by different fields, i.e. some results match by email, some by first name, and some by last name" do
        FactoryGirl.create(:user, :activated, first_name: "test", last_name: "user",   email: 'user1@example.com') # first name
        FactoryGirl.create(:user, :activated, first_name: "user", last_name: "1test",  email: 'user2@example.com') # last name
        FactoryGirl.create(:user, :activated, first_name: "user3", last_name: "user",  email: 'test3@example.com') # email
        FactoryGirl.create(:user, :activated, first_name: "user4", last_name: "user", email: 'user4@example.com') # miss
        subject
        expect(JSON.parse(response.body)).to match_array([{"name"=>"test user", "email"=>"user1@example.com"},
                                                          {"name"=>"user 1test", "email"=>"user2@example.com"},
                                                          {"name"=>"user3 user",  "email"=>"test3@example.com"}])
      end

      it "only searches in activated (confirmed and assigned a role) users" do
        FactoryGirl.create(:user, first_name: 'test', last_name: 'test', email: 'test1@example.com', confirmed_at: Time.now, role: 'monitor')
        FactoryGirl.create(:user, first_name: 'test', last_name: 'test', email: 'test2@example.com', confirmed_at: Time.now)
        FactoryGirl.create(:user, first_name: 'test', last_name: 'test', email: 'test3@example.com', role: 'monitor')
        subject
        expect(JSON.parse(response.body)).to eql([{"name"=>"test test", "email"=>"test1@example.com"}])
      end

      it "returns at most 5 results" do
        7.times { |i| FactoryGirl.create(:user, :activated, first_name: "test#{i}") }
        subject
        expect(JSON.parse(response.body).length).to eql(5)
      end
    end
  end
end
