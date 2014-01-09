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

# Adds the {#locale_field} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend LocaleField
#     locale_field :my_field
#   end

module LocaleField

  # @overload locale_field(field, ..., options={})
  #   Defines one or more fields that should be accessed as {Locale} objects and
  #   serialized in RFC 5646 format. When passed a field name such as `:locale`,
  #   this method will create a getter and setter that work with {Locale}s, and
  #   store the RFC 5646 value in a database column called `rfc5646_locale`.
  #
  #   A validation will be added to verify the field is a proper RFC 5646
  #   locale (though the locale doesn't need to exist in the IANA database).
  #
  #   @param [Symbol] field The name of a field to define as a locale field.
  #   @param [Hash] options Additional options.
  #   @option options [Proc] reader A Proc that converts a serialized value into
  #     a value with Locale instances. By default just converts an RFC 5646
  #     string into a locale. Override this variable for more complex data
  #     types, such as arrays of Locales.
  #   @option options [Proc] writer a Proc that converts a Locale into a
  #     serialized value. By default just calls `#rfc5646` on the Locale.
  #     Override this variable for more complex data types, such as arrays of
  #     Locales.
  #   @option options [Symbol] from The database column that will store the
  #     serialized Locale. By default it's the name of the field with "rfc5646_"
  #     prepended.
  #   @option options [Hash] validations Additional validations or validation
  #     options to apply to the field.

  def locale_field(*fields)
    options = fields.extract_options!

    reader = options[:reader] || ->(value) { Locale.from_rfc5646(value) }
    writer = options[:writer] || ->(value) { value.rfc5646 }

    fields.each do |field|
      field_from = options[:from] || :"rfc5646_#{field}"

      define_method(field) do
        value = send(field_from)
        value ? reader.(value) : nil
      end

      define_method(:"#{field}=") do |value|
        send :"#{field_from}=", (value ? writer.(value) : nil)
      end

      validate field, (options[:validations] || {}).reverse_merge(
          format:   {with: Locale::RFC5646_FORMAT}
      )
    end
  end
end
