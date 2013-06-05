# Copyright 2013 Square Inc.
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

describe Importer::Properties do
  include ImporterTesting

  context "[importing]" do
    before(:each) do
      @project  = FactoryGirl.create(:project, base_rfc5646_locale: 'en-US')
      @blob     = FactoryGirl.create(:fake_blob, project: @project)
      @importer = Importer::Properties.new(@blob, 'some/path')
    end

    it "should import strings from .properties files" do
      test_importer @importer, <<-PROPERTIES
user.does.not.have.permission.to.accept.this.payment=User does not have permission to accept this payment.
# Comment
user.does.not.have.permission.to.accept.payment.to.requested.user=User does not have permission to accept this payment to the requested user.
app.not.found=App not found.
      PROPERTIES

      @project.keys.count.should eql(3)
      @project.keys.for_key('user.does.not.have.permission.to.accept.this.payment').first.translations.find_by_rfc5646_locale('en-US').
          copy.should eql('User does not have permission to accept this payment.')
      @project.keys.for_key('user.does.not.have.permission.to.accept.payment.to.requested.user').first.translations.find_by_rfc5646_locale('en-US').
          copy.should eql('User does not have permission to accept this payment to the requested user.')
      @project.keys.for_key('app.not.found').first.translations.find_by_rfc5646_locale('en-US').
          copy.should eql('App not found.')
    end
  end
end
