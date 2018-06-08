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

RSpec.describe Article do
  context "[import!]" do
    it "triggers an import after creation" do
      article = FactoryBot.build(:article)
      expect(article).to receive(:import!).once
      article.save!
    end

    it "triggers an import if sections_hash changes; doesn't force Article's sections to reimport" do
      article = FactoryBot.create(:article, sections_hash: {"main" => "hello"})
      expect(article.reload).to receive(:import!).once.with(false)
      article.update!(sections_hash: {"main" => "hi"})
    end

    it "triggers an import if targeted_rfc5646_locales changes; forces Article's sections to reimport" do
      article = FactoryBot.create(:article, targeted_rfc5646_locales: {'en'=>true})
      expect(article.reload).to receive(:import!).once.with(true)
      article.update!(targeted_rfc5646_locales: {'es'=>true})
    end

    it "doesn't trigger an import if other fields such as description or email change" do
      article = FactoryBot.create(:article, description: "old description", email: "old@example.com")
      expect(article.reload).to_not receive(:import!)
      article.update!(description: "new description", email: "new@example.com")
    end
  end

  context "[article webhook]" do
    context "[with an article_webhook_url]" do
      before(:each) do
        @project = FactoryBot.create(:project, article_webhook_url: "http://example.com")
        @article = FactoryBot.create(:article, project: @project, ready: false)
      end

      it "does not enqueue an ArticleWebhookPinger job when an article is created" do
        @article = FactoryBot.create(:article, project: @project, ready: true)
        expect(ArticleWebhookPinger).to_not receive(:perform_once)
        @article.save!
      end

      it "enqueues a ArticleWebhookPinger job when a article becomes ready" do
        @article.ready = true
        expect(ArticleWebhookPinger).to receive(:perform_once)
        @article.save!
      end

      it "doesn't enqueue a ArticleWebhookPinger job when a article becomes not-ready" do
        @article.update!(ready: true)
        @article.ready = false
        expect(ArticleWebhookPinger).to_not receive(:perform_once)
        @article.save!
      end

      it "doesn't enqueue a ArticleWebhookPinger when a article is updated without changing its ready field" do
        @article.update(name: 'test_article')
        expect(ArticleWebhookPinger).to_not receive(:perform_once)
        @article.save!
      end
    end

    context "[without an article_webhook_url]" do
      before(:each) do
        @project = FactoryBot.create(:project, article_webhook_url: nil)
        @article = FactoryBot.create(:article, project: @project, ready: false)
      end

      it "does not enqueue a ArticleWebhookPinger job when a article's ready field changes" do
        @article.ready = true
        expect(ArticleWebhookPinger).to_not receive(:perform_once)
        @article.save!
      end
    end
  end
end
