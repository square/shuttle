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

describe SearchableField do
  it "should automatically set the TSVECTOR field" do
    t = FactoryGirl.create(:translation, copy: "Searchable copy")
    t.reload.searchable_copy.should eql("'copy':2 'searchabl':1")
    t.update_attribute :copy, "New copy"
    t.reload.searchable_copy.should eql("'copy':2 'new':1")
  end

  it "should not set the TSVECTOR field if the value is not changed" do
    t = FactoryGirl.create(:translation, copy: "Searchable copy")
    t.reload.searchable_copy.should eql("'copy':2 'searchabl':1")
    Translation.connection.should_not_receive(:exec_update).with(/TO_TSVECTOR/, anything, anything)
    #TODO implementation detail in spec
    t.update_attribute :approved, false
  end

  it "should use a custom :language option" do
    k = FactoryGirl.create(:key, key: "Some key")
    Key.connection.should_receive(:exec_update).once.with(/TO_TSVECTOR\('simple', /, anything, anything).and_call_original
    Key.connection.stub(:exec_update).and_call_original
    #TODO implementation detail in spec
    k.reload.update_attribute :original_key, "New key"
  end

  it "should use a custom :language_from option" do
    t = FactoryGirl.create(:translation, rfc5646_locale: 'de-DE', copy: "Searchable copy")
    Translation.connection.should_receive(:exec_update).once.with(/TO_TSVECTOR\('french', /, anything, anything).and_call_original
    Key.connection.stub(:exec_update).and_call_original
    #TODO implementation detail in spec
    t.copy = "New copy"
    t.rfc5646_locale = 'fr-CA'
    t.save!
  end

  it "should override the column with :search_column" do
    pending "No models use this option"
  end
end
