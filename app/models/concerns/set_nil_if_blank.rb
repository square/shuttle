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

# Adds the {#set_nil_if_blank} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend SetNilIfBlank
#     set_nil_if_blank :my_field
#   end

module SetNilIfBlank

  # @overload set_nil_if_blank(field, ...)
  #   Specifies that the given field(s) should be set to nil if their values are
  #   `#blank?`.
  #   @param [Symbol] field The name of a field to set nil if blank.

  def set_nil_if_blank(*fields)
    fields.each do |field|
      before_validation { |obj| obj.send :"#{field}=", nil if obj.send(field).blank? }
    end
  end
end
