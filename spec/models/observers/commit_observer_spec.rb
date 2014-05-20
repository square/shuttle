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

describe Commit do
  context "[mailing import errors]" do
    it "should email if commit has import errors after submitting twice" do
      user = FactoryGirl.create(:user)
      ActionMailer::Base.deliveries.clear
      project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)
      commit  = project.commit!('a82cf69f11618883e534189dea61f234da914462', other_fields: {user: user})
      expect(ActionMailer::Base.deliveries.map(&:subject)).to include("[Shuttle] Error(s) occurred during the import")

      ActionMailer::Base.deliveries.clear
      commit  = project.commit!('HEAD', other_fields: {user: user})
      expect(ActionMailer::Base.deliveries.map(&:subject)).to include("[Shuttle] Error(s) occurred during the import")
    end
  end
end