class AddArticleToTranslationChanges < ActiveRecord::Migration
  def change
    add_reference :translation_changes, :article, index: true, foreign_key: true
  end
end
