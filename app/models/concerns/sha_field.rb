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

require 'digest/sha2'

# Adds the {#sha_field} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend ShaField
#     sha_field :my_field
#   end

module ShaField

  # @overload sha_field(field, ..., options={})
  #   Specifies that the field(s) are accessible as digested SHA2 values. The
  #   corresponding columns should be of `BYTEA` format so that the SHA2 value
  #   can be stored in as few bytes as possible. The method will create a
  #   getter and setter **with a different name** that expose the field value as
  #   a lowercase hexadecimal string. Use the `:column` option to specify the
  #   `BYTEA` column.
  #
  #   @param [Symbol] field The name of a `BYTEA` column to treat as a SHA2
  #     value.
  #   @param [Hash] options Additional options.
  #   @option options [Symbol] column The `BYTEA` column that will store the
  #     digest value. By default it's the field name plus "_raw" appended.
  #   @option options [Hash<Symbol, [boolean, Hash]>] validations ({})
  #     Additional validations or validation options to apply to the field.
  #   @option options [Symbol] scope If set, also creates a named scope that
  #     filters by the given hex SHA values.

  def sha_field(*fields)
    options = fields.extract_options!

    fields.each do |field|
      column_name = options[:column] || :"#{field}_raw"

      define_method(field) do
        ShaField::hex send(column_name)
      end

      define_method(:"#{field}=") do |sha|
        send :"#{column_name}=", ShaField::unhex(sha)
        sha
      end

      if options[:scope]
        scope options[:scope], ->(*values) {
          column_query = "#{connection.quote_table_name table_name}.#{connection.quote_column_name column_name}"
          if values.size == 1 && values.first.kind_of?(Enumerable)
            raw = values.first.map { |v| ShaField::unhex(v) }
            where("#{column_query} IN (#{raw.map { |v| quote_bytea(v) }.join(', ')})")
          elsif values.size == 1
            raw = ShaField::unhex(values.first)
            where("#{column_query} = #{quote_bytea raw}")
          else
            raw = values.map { |v| ShaField::unhex(v) }
            where("#{column_query} IN (#{raw.map { |v| quote_bytea(v) }.join(', ')})")
          end
        }
      end
    end

    validates *fields, (options[:validations] || {}).reverse_merge(
        format: {with: /[0-9a-fA-F]+/, message: I18n.t('errors.messages.invalid_sha')},
    )
  end

  # @private
  def self.unhex(sha)
    sha ? [sha].pack('H*') : nil
  end

  # @private
  def self.hex(val)
    val ? val.unpack('H*').first : nil
  end

  def quote_bytea(raw)
    "E'#{connection.escape_bytea raw}'::bytea"
  end
end
