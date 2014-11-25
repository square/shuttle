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

describe Devise::ConfirmationsController do
  before :each do
    @request.env["devise.mapping"] = Devise.mappings[:user]

    app_config = Shuttle::Configuration.app
    Shuttle::Configuration.stub(:app).and_return(app_config.merge(domains_to_get_monitor_role_after_email_confirmation: ['example.com']))
  end

  it "gives monitor permission to user after confirmation if their email address domain is a priviliged one" do
    user = FactoryGirl.create(:user, role: nil, email: "foo@example.com")
    expect(user.email).to eql('foo@example.com')
    user.send :generate_confirmation_token!

    get :show, { confirmation_token: user.instance_eval { @raw_confirmation_token } }

    expect(user.reload.confirmed_at).to_not be_nil
    expect(user.role).to eql('monitor')
  end

  it "does not change the permission of user after confirmation if their email address domain is NOT a priviliged one" do
    user = FactoryGirl.create(:user, role: nil, email: "foo@notpriviliged.com")
    expect(user.email).to eql('foo@notpriviliged.com')
    user.send :generate_confirmation_token!

    get :show, { confirmation_token: user.instance_eval { @raw_confirmation_token } }

    expect(user.reload.confirmed_at).to_not be_nil
    expect(user.role).to be_nil
  end
end
