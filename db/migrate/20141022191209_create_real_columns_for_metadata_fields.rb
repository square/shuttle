class CreateRealColumnsForMetadataFields < ActiveRecord::Migration
  def up
    add_column :users, :first_name,               :string
    add_column :users, :last_name,                :string
    add_column :users, :encrypted_password,       :string
    add_column :users, :remember_created_at,      :datetime
    add_column :users, :current_sign_in_at,       :datetime
    add_column :users, :last_sign_in_at,          :datetime
    add_column :users, :current_sign_in_ip,       :string
    add_column :users, :last_sign_in_ip,          :string
    add_column :users, :confirmed_at,             :datetime
    add_column :users, :confirmation_sent_at,     :datetime
    add_column :users, :locked_at,                :datetime
    add_column :users, :reset_password_sent_at,   :datetime
    add_column :users, :approved_rfc5646_locales, :text

    execute "ALTER TABLE users ADD CONSTRAINT encrypted_password_exists CHECK (char_length(encrypted_password) > 20);"

    if User.respond_to? :metadata_column_fields
      deprecated_metadata_columns = User.metadata_column_fields.keys.select { |k| k.to_s.start_with?('deprecated__')}

      User.all.each do |user|
        deprecated_metadata_columns.each do |depr_col|
          col = depr_col.to_s.split('deprecated__')[1]
          user.send :"#{col}=", user.send(depr_col)
        end
        user.save!
      end
    end

    change_column_null :users, :first_name, false
    change_column_null :users, :last_name, false
    change_column_null :users, :encrypted_password, false
  end

  def down
    raise "Rollback disabled"
  end
end
