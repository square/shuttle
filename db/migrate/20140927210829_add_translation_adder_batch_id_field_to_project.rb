class AddTranslationAdderBatchIdFieldToProject < ActiveRecord::Migration
  def change
    add_column :projects, :translation_adder_batch_id, :string
  end
end
