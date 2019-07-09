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

require "rails_helper"

RSpec.describe FencerValidationMailer do
  describe "#suspicious_source_found" do
    before :each do
      @project = FactoryBot.create(:project)
      @commit = FactoryBot.create(:commit, project: @project, author: 'Foo Bar', author_email: "foo@example.com")
      @key = FactoryBot.create(:key, project: @project)

      @translation = FactoryBot.create(:translation, translated: false, key: @key)
      @key.reload

      ActionMailer::Base.deliveries.clear
    end

    it 'sends an email to shuttle and localization teams' do
      fake_suspicious_keys_errors = [[@key, 'Violate fencers: FakeFencer']]

      mail = FencerValidationMailer.suspicious_source_found(@commit, fake_suspicious_keys_errors).deliver_now

      expect(mail.subject).to eq('[NO ACTION REQUIRED] [Shuttle Staging] Found suspicious source strings')
      expect(mail.body).to include('Violate fencers: FakeFencer')
    end
  end
end
