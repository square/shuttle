class AddMultiLocaleSettingToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :disable_locale_association_checkbox_settings, :boolean, default: false, null: false
  end
end
