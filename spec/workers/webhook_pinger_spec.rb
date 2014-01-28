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
describe WebhookPinger do
  before(:each) do
    @commit = FactoryGirl.create(:commit)
  end

  describe "#perform" do
    subject { WebhookPinger.new }
    it "sends an http request to the project webhook_url if one is defined" do
      url = "http://www.example.com"
      @commit.project.webhook_url = url
      @commit.project.save!
      expect(HTTParty).to receive(:post).with(url, anything())
      subject.perform(@commit.id)
    end
    it "doesnt send anything if no webhook_url is defined on the project" do
      expect(@commit.project.webhook_url).to be_blank
      expect(HTTParty).not_to receive(:post)
      subject.perform(@commit.id)
    end
  end
end
