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
    article = nil

    # This call will disable all sidekiq jobs in the call chain.
    # In this case, we only have ArticleImporter and we need to stub it to prevent
    # it form creating keys. If you do need some sidekiq jobs to run, you need refactor this line.
    Sidekiq::Testing.fake! do
      article = FactoryGirl.create(:article, ready: false)
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => article.id})
      ArticleRecalculator.new.perform(article.id)
    end
    expect(article.reload).to be_ready
  end
end
