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
#     digest_field :my_field, from: :text_field
#   end

module DigestField
  include ShaField

  # @overload digest_field(field, ..., options={})
  #   Specifies that the field(s) save their digested SHA2 values to a different
  #   field automatically. See the {ShaField} module for more information about
  #   how SHA2 values are stored and accessed, and additional options that can
  #   be passed to this method.
  #
  #   @param [Symbol] field The name of a field whose value should be digested.
  #   @param [Hash] options Additional options.
  #   @option options [Symbol] to The name of a `BYTEA` column to treat as a
  #     SHA2 value. By default, it's the field name with "_sha" appended.
  #   @option options [Fixnum] width (32) The size of the SHA2 value, in bytes.
  #     The number of characters necessary to represent the SHA2 in hex is twice
  #     this value.
  #   @option options [Symbol] scope If set, also creates a named scope that
  #     filters by the given **original column** (not hex digest) values.

  def digest_field(*fields)
    options = fields.extract_options!

    width      = options.delete(:width) || 32
    scope_name = options.delete(:scope) # don't fall back to sha_field's scope feature
    source_fields    = []

    fields.each do |field|
      source_field = options[:to] || :"#{field}_sha"
      source_fields << source_field
      column = :"#{source_field}_raw"

      before_validation do |object|
        if (value = object.send(field))
          object.send :"#{source_field}=", Digest::SHA2.hexdigest(value)[0, width*2]
        else
          object.send :"#{source_field}=", nil
        end
      end

      # custom named scope handling: searches not by the digested value but the original value
      if scope_name
        scope scope_name, ->(*values) {
          column_query = "#{connection.quote_table_name table_name}.#{connection.quote_column_name column}"
          if values.size == 1 && values.first.kind_of?(Enumerable)
            raw = values.first.map { |v| Digest::SHA2.digest(v) }
            where("#{column_query} IN (#{raw.map { |v| quote_bytea(v) }.join(', ')})")
          elsif values.size == 1
            raw = Digest::SHA2.digest(values.first)
            where("#{column_query} = #{quote_bytea raw}")
          else
            raw = values.map { |v| Digest::SHA2.digest(v) }
            where("#{column_query} IN (#{raw.map { |v| quote_bytea(v) }.join(', ')})")
          end
        }
      end
    end

    source_fields << options
    sha_field *source_fields
  end
end
