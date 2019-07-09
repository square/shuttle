class AddDeviseExtenstion < ActiveRecord::Migration
  def change
    # https://github.com/phatworx/devise_security_extension

    # Expirable on inactivity
    add_column :users, :last_activity_at, :datetime
    add_column :users, :expired_at, :datetime
    add_index :users, :last_activity_at
    add_index :users, :expired_at
  end
end
