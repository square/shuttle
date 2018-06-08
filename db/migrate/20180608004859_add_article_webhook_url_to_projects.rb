class AddArticleWebhookUrlToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :article_webhook_url, :string
  end
end
