class SetDefaultToFalseForUncheckableInLocaleAssociations < ActiveRecord::Migration
  def up
    change_column_default :locale_associations, :uncheckable, false
  end

  def down
    change_column_default :locale_associations, :uncheckable, true
  end
end
