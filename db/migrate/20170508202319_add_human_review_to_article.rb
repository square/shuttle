class AddHumanReviewToArticle < ActiveRecord::Migration
  def change
    add_column :articles, :human_review, :boolean, default: true, null: false
  end
end
