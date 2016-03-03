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

# Adds the {#digest_field} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend DigestField
#     digest_field :my_field, scope: :for_my_field
#   end

module DigestField

  SHA_FORMAT = /\A[0-9a-fA-F]+\z/

  # @overload digest_field(field, options={})
  #   Specifies that the field save its digested SHA2 value to a different
  #   field as bytea, automatically.
  #
  #   @param [Symbol] field The name of a field whose value should be digested.
  #   @param [Hash] options Additional options.
  #   @option options [Symbol] scope If set, also creates a named scope that
  #     filters by the given **original column** (not hex digest) value.

  def digest_field(field, options={})
    scope_name = options.delete(:scope)

    digest_field_legacy(field, scope_name)
    digest_field_new(field, scope_name)
  end

  private

  def digest_field_legacy(field, scope_name)
    legacy_sha_field_name = :"#{field}_sha_legacy"
    legacy_sha_raw_db_column = :"#{field}_sha_raw"

    define_method(legacy_sha_field_name) do
      DigestField::hex_to_bytea send(legacy_sha_raw_db_column)
    end

    before_validation do |object|
      value = object.send(field)
      value_sha_raw = value ? Digest::SHA2.digest(value) : nil
      object.send :"#{legacy_sha_raw_db_column}=", value_sha_raw
    end

    validate do |object|
      legacy_value_sha = DigestField::bytea_to_hex(object.send(legacy_sha_raw_db_column))
      unless SHA_FORMAT =~ legacy_value_sha
        object.errors.add(legacy_sha_raw_db_column, I18n.t('errors.messages.invalid_sha'))
      end
    end

    # custom named scope handling: searches not by the digested value but the original value
    if scope_name
      scope scope_name, ->(value) {
        column_query = "#{connection.quote_table_name table_name}.#{connection.quote_column_name legacy_sha_raw_db_column}"
        raw = Digest::SHA2.digest(value)
        where("#{column_query} = #{quote_bytea raw}")
      }
    end
  end

  def digest_field_new(field, scope_name)
    sha_field_name = :"#{field}_sha"

    before_validation do |object|
      value = object.send(field)
      value_sha = value ? Digest::SHA2.hexdigest(value) : nil
      object.send :"#{sha_field_name}=", value_sha
    end

    validates sha_field_name, format: {with: SHA_FORMAT, message: I18n.t('errors.messages.invalid_sha')}

    # if scope_name
    #   scope scope_name, ->(value) do
    #     column_query = "#{connection.quote_table_name table_name}.#{connection.quote_column_name sha_field_name}"
    #     value_sha = Digest::SHA2.hexdigest(value)
    #     where(column_query => value_sha)
    #   end
    # end
  end

  # @private
  def self.bytea_to_hex(val)
    val ? val.unpack('H*').first : nil
  end

  # @private
  def self.hex_to_bytea(val)
    val ? val.unpack('H*').first : nil
  end

  def quote_bytea(raw)
    "E'#{connection.escape_bytea raw}'::bytea"
  end
end
