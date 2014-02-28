class AddConfirmableToDevise < ActiveRecord::Migration
  def up
    add_column :users, :confirmation_token, :string

    add_index  :users, :confirmation_token, :unique => true
    User.all.each { |u| u.update_attribute(:confirmed_at, Time.now) }

  end

  def down
    remove_columns :users, :confirmation_token
  end
end
