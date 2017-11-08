class AddTmMatchPercentageToTranslations < ActiveRecord::Migration
  def change
    add_column :translations, :tm_match, :decimal
    add_column :translations, :translation_date, :datetime
  end
end
