# encoding: utf-8

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

# encoding: utf-8

# Helper methods that apply to all views.

module ApplicationHelper

  # A composition of `pluralize` and `number_with_delimiter.`
  #
  # @param [Fixnum] count The number of things.
  # @param [String] singular The name of a thing.
  # @param [String] plural The name of two or more things.
  # @return [String] A pluralized description of the things.

  def pluralize_with_delimiter(count, singular, plural=nil)
    "#{number_with_delimiter(count) || 0} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
  end
end
