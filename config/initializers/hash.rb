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

# Extensions to the Hash class.

class Hash

  # Recursively applies a block to this hash and all other hashes underneath it.
  # Scans any Array values for nested hashes as well.
  #
  # @yield [hash] The block to recursively apply.
  # @yieldparam [Hash] hash This hash or a nested hash underneath it.
  # @return The result of the block.

  def recursively(&block)
    result = yield self
    each do |_, value|
      case value
        when Hash
          value.recursively(&block)
        when Array
          value._hash_recursively(&block)
      end
    end

    result
  end
end

class Array
  # @private
  def _hash_recursively(&block)
    each do |value|
      case value
        when Hash
          value.recursively(&block)
        when Array
          value._hash_recursively(&block)
      end
    end
  end
end
