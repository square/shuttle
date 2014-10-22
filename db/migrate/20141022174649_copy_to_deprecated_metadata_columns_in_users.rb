class CopyToDeprecatedMetadataColumnsInUsers < ActiveRecord::Migration
  def up
    if User.respond_to? :metadata_column_fields
      original_metadata_columns = User.metadata_column_fields.keys.select { |k| !k.to_s.start_with?('deprecated__')}

      User.all.each do |user|
        original_metadata_columns.each do |col|
          user.send :"deprecated__#{col}=", user.send(col)
        end
        user.save!
      end
    end
  end

  def down
    raise "Rollback disabled"
  end
end
