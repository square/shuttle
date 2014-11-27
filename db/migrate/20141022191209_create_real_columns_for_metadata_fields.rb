# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

class CreateRealColumnsForMetadataFields < ActiveRecord::Migration
  def up
    # create temporary columns
    add_column :users, :deprecated__first_name,               :string
    add_column :users, :deprecated__last_name,                :string
    add_column :users, :deprecated__encrypted_password,       :string
    add_column :users, :deprecated__remember_created_at,      :datetime
    add_column :users, :deprecated__current_sign_in_at,       :datetime
    add_column :users, :deprecated__last_sign_in_at,          :datetime
    add_column :users, :deprecated__current_sign_in_ip,       :string
    add_column :users, :deprecated__last_sign_in_ip,          :string
    add_column :users, :deprecated__confirmed_at,             :datetime
    add_column :users, :deprecated__confirmation_sent_at,     :datetime
    add_column :users, :deprecated__locked_at,                :datetime
    add_column :users, :deprecated__reset_password_sent_at,   :datetime
    add_column :users, :deprecated__approved_rfc5646_locales, :text

    # populate temporary columns
    deprecated_metadata_columns = User.columns.map(&:name).select {|c| c.start_with?("deprecated__")}
    User.find_each do |user|
      metadata = JSON.parse(user.metadata)
      hsh = {}
      deprecated_metadata_columns.each do |column_name|
        hsh[:"#{column_name}"] = metadata[column_name.split("deprecated__").last]
      end
      user.update_columns hsh
    end

    # rename temporary columns to permanent columns
    rename_column :users, :deprecated__first_name,               :first_name
    rename_column :users, :deprecated__last_name,                :last_name
    rename_column :users, :deprecated__encrypted_password,       :encrypted_password
    rename_column :users, :deprecated__remember_created_at,      :remember_created_at
    rename_column :users, :deprecated__current_sign_in_at,       :current_sign_in_at
    rename_column :users, :deprecated__last_sign_in_at,          :last_sign_in_at
    rename_column :users, :deprecated__current_sign_in_ip,       :current_sign_in_ip
    rename_column :users, :deprecated__last_sign_in_ip,          :last_sign_in_ip
    rename_column :users, :deprecated__confirmed_at,             :confirmed_at
    rename_column :users, :deprecated__confirmation_sent_at,     :confirmation_sent_at
    rename_column :users, :deprecated__locked_at,                :locked_at
    rename_column :users, :deprecated__reset_password_sent_at,   :reset_password_sent_at
    rename_column :users, :deprecated__approved_rfc5646_locales, :approved_rfc5646_locales

    execute "ALTER TABLE users ADD CONSTRAINT encrypted_password_exists CHECK (char_length(encrypted_password) > 20);"
    change_column_null :users, :first_name, false
    change_column_null :users, :last_name, false
    change_column_null :users, :encrypted_password, false

    User.reset_column_information
  end
end
