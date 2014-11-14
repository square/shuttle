class RenameLocaleAssociationsUncheckableColumnToUncheckDisabled < ActiveRecord::Migration
  def change
    rename_column :locale_associations, :uncheckable, :uncheck_disabled
  end
end
