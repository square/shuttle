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

# Implements basic mediator functionality such as keeping track of errors and
# providing helper methods to interact with them.
#
# Fields
# ======
#
# |          |                                                                                  |
# |:---------|:---------------------------------------------------------------------------------|
# | `errors` | an array which should keep track of errors that happened in the inheriting class |

class BasicMediator

  attr_reader :errors

  def initialize
    @errors = []
  end

  # @return [true, false] true if no errors have been recorded, false otherwise
  def success?
    @errors.blank?
  end

  # @return [true, false] true if any errors have been recorded, false otherwise
  def failure?
    !success?
  end

  private

  # Add multiple errors at once
  #
  # @param [Array<String>] msgs a list of error messages in String format

  def add_errors(msgs)
    @errors.push(*msgs)
  end

  # Add a single error
  #
  # @param [String] msg an error message in String format

  def add_error(msg)
    @errors.push(msg)
  end
end
