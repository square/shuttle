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

# After a {Article}'s has been marked as "ready", we need to let the client
# system know. Looks up the article webhook URL for the {Project} and perform an HTTP
# post with the article information.

class ArticleWebhookPinger
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Executes this worker.
  #
  # @param [Fixnum] article_id The ID of a Article.

  def perform(article_id)
    article = Article.find(article_id)
    return unless article.project.article_webhook?

    if article.project.article_webhook? && article.ready?
      post_parameters = {
        article_name: article.name,
        project_name: article.project.name,
        ready: article.ready?,
      }
      HTTParty.post(article.project.article_webhook_url, {timeout: 5, body: post_parameters })
    end
  end

  include SidekiqLocking
end
