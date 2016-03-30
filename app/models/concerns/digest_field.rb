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
  #   field as hex sha, automatically.
  #
  #   @param [Symbol] field The name of a field whose value should be digested.
  #   @param [Hash] options Additional options.
  #   @option options [Symbol] scope If set, also creates a named scope that
  #     filters by the given **original column** (not hex digest) value.

  def digest_field(field, options={})
    scope_name = options.delete(:scope)
    sha_field_name = :"#{field}_sha"

    before_validation do |object|
      value = object.send(field)
      value_sha = value ? Digest::SHA2.hexdigest(value) : nil
      object.send :"#{sha_field_name}=", value_sha
    end

    validates sha_field_name, format: {with: SHA_FORMAT, message: I18n.t('errors.messages.invalid_sha')}

    if scope_name
      scope scope_name, ->(value) do
        value_sha = Digest::SHA2.hexdigest(value)
        where(table_name => { sha_field_name => value_sha })
      end
    end
  end
end
