class AddUniqueConstraintToLocaleAssociation < ActiveRecord::Migration
  def change
    add_index :locale_associations, [:source_rfc5646_locale, :target_rfc5646_locale], :unique => true, name: "index_locale_associations_on_source_and_target_rfc5646_locales"
  end
end
