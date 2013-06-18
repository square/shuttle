# Copyright 2013 Square Inc.
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

# Adds the {#prefix_field} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend PrefixField
#     prefix_field :my_field
#   end

module PrefixField

  # @overload prefix_field(field, ..., options={})
  #   Specifies that one or more fields should have the initial parts of their
  #   values to set corresponding prefix fields. This allows larger fields to be
  #   sortable while only requiring that smaller fields be indexed.
  #
  #   @param [Symbol] field The name of a text or string field to be prefixed.
  #   @param [Hash] options Additional options.
  #   @option options [Symbol] prefix_column Specifies the database column that
  #     should store the prefixed value. By default it's the name of the field
  #     with "_prefix" appended.
  #   @option options [Integer] length (5) The number of characters to include
  #     in the prefix.

  def prefix_field(*fields)
    options = fields.extract_options!

    before_save do |object|
      fields.each do |field|
        column = options[:prefix_column] || :"#{field}_prefix"
        object.send :"#{column}=", object.send(field)[0, options[:length] || 5]
      end
    end
  end
end
