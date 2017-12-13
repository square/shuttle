class AddReviewDateToTranslation < ActiveRecord::Migration
  def change
    add_column :translations, :review_date, :datetime
  end
end
