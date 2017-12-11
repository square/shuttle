# Copyright 2017 Square Inc.
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

# Mixin that adds support for tracking abstract and concrete subclasses of a
# class.
#
# @example
#   class Base
#      extend AbstractClass
#   end
#
#   class Abstract < Base
#     abstract!
#   end
#
#   class Concrete < Abstract
#   end
#
#   Base.implementations #=> [Concrete]

module AbstractClass

  # Call this method in abstract subclasses of your base class.

  def abstract!
    @abstract = true
  end

  # @return [true, false] Whether this subclass is abstract.

  def abstract?
    @abstract
  end

  # @return [Array<Class>] An array of all non-abstract subclasses of this
  #   class.

  def implementations
    if superclass.respond_to?(:implementations)
      superclass.implementations
    else
      _implementations.reject(&:abstract?)
    end
  end

  # @private
  def _implementations
    if superclass.respond_to?(:_implementations)
      superclass._implementations
    else
      @_implementations ||= Array.new
    end
  end

  # @private
  def inherited(subclass)
    _implementations << subclass
  end
end
