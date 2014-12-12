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

describe ArticleRecalculator do
  it "should recalculate Article readiness" do
    ArticleImporter.any_instance.stub(:perform) # prevent it from creating keys
    article = FactoryGirl.create(:article, ready: false)
    ArticleRecalculator.new.perform(article.id)
    expect(article.reload).to be_ready
  end
end
