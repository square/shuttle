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

require 'rails_helper'
RSpec.describe ArticleWebhookPinger do
  before(:each) do
    @article = FactoryBot.create(:article, name: 'test_webhook-article')
  end

  describe "#perform" do
    subject { ArticleWebhookPinger.new }

    it "sends an http request to the project article_webhook_url if one is defined" do
      url = "http://www.example.com"
      @article.project.update(article_webhook_url: url)
      @article.update(ready: true)
      expected_params = {
        article_name: 'test_webhook-article',
        project_name: @article.project,
        ready: true,
      }
      expect(HTTParty).to receive(:post).with(url, anything())
      subject.perform(@article.id)
    end

    it "doesnt send anything if no article_webhook_url is defined on the project" do
      @article.project.update(article_webhook_url: nil)
      expect(HTTParty).not_to receive(:post)
      subject.perform(@article.id)
    end
  end
end
