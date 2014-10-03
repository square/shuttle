class AddLocaleIndexToTranslations < ActiveRecord::Migration
  def change
    add_index :translations, :rfc5646_locale
  end
end
