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

# Reimplement the #permit method to allow an empty hash to stand for
# "permit everything", much in the same way that an empty array stands for
# "permit any array".  This allows us to properly use objects with hash-type
# metadata fields, such as Project#targeted_rfc5646_locales.

class ActionController::Parameters
  EMPTY_HASH = {}
  def hash_filter(params, filter)
    filter = filter.with_indifferent_access

    # Slicing filters out non-declared keys.
    slice(*filter.keys).each do |key, value|
      return unless value

      if filter[key] == EMPTY_ARRAY
        # Declaration { comment_ids: [] }.
        array_of_permitted_scalars_filter(params, key)
      else
        # Declaration { user: :name } or { user: [:name, :age, { address: ... }] }.
        params[key] = each_element(value) do |element|
          if element.is_a?(Hash)
            element = self.class.new(element) unless element.respond_to?(:permit)
            if filter[key] == EMPTY_HASH
              element.permit(*element.keys)
            else
              element.permit(*Array.wrap(filter[key]))
            end
          end
        end
      end
    end
  end
end
