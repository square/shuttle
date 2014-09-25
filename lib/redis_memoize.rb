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

# Method memoization a la `ActiveSupport::Memoize`, only in Redis. To use this
# feature, you need to extend your class with this module, and implement a
# `redis_memoize_key` method that returns a serializable representation of the
# receiver.
#
# Return values are stored in YAML format.
#
# @example
#   class MyClass
#     extend RedisMemoize
#
#     def my_method(arg1, arg2)
#       do_something_intensive arg1
#       do_something_intensive arg2
#     end
#     redis_memoize :my_method
#
#     def redis_memoize_key() to_param end
#   end

module RedisMemoize

  # Specifies that the given method should have its return values memoized in
  # Redis. Arbitrary arguments are supported, so long as they can be uniquely
  # serialized in `inspect` form.
  #
  # @param [Symbol] method The name of the method to memoize.

  def redis_memoize(method)
    define_method(:"#{method}_with_memoize") do |*args|
      key = RedisMemoize.redis_memoize_key(self, method, args)

      if (yml = Shuttle::Redis.get(key))
        YAML.load yml
      else
        value = send(:"#{method}_without_memoize", *args)
        Shuttle::Redis.set key, value.to_yaml
        value
      end
    end
    alias_method_chain method, :memoize
  end

  # Clears all memoized return values pertaining to the given object.
  #
  # @param [Object] object An object to clear memoized return values for.
  # @param [Symbol] method A method to clear memoized return values for. If
  #   omitted, all methods' return valeus are cleared.

  def flush_memoizations(object, method=nil)
    keys = if method
             "RedisMemoize:#{object.class}:#{method}:*"
           else
             "RedisMemoize:#{object.class}:*"
           end

    keys_to_delete = Shuttle::Redis.keys(keys)
    Shuttle::Redis.del(*keys_to_delete) unless keys_to_delete.empty?
  end

  # @private
  def self.redis_memoize_key(object, method, args)
    "RedisMemoize:#{object.class}:#{method}:#{object.redis_memoize_key}:#{args.inspect}"
  end
end
