class AddWordsCountToTranslations < ActiveRecord::Migration
  def up
    execute "ALTER TABLE translations ADD COLUMN words_count INTEGER DEFAULT 0"

    say_with_time "Updating translations..." do
      Translation.find_each do |t|
        t.send :count_words
        t.save!
      end
    end

    execute "ALTER TABLE translations ALTER words_count SET NOT NULL"
  end

  def down
    execute "ALTER TABLE translations DROP COLUMN words_count"
  end
end
