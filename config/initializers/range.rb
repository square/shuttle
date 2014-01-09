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

# Adds helpful methods to `Range`.

class Range

  # Returns the inverse of a set of ranges. The inverse is a set of ranges
  # covering all values _not_ included in the given set of ranges.
  #
  # @param [Range] containing_range The range of all possible values, whether
  #   or not they are included in the range set.
  # @param [Array<Range>] ranges The set of ranges to invert.
  # @return [Array<Range>] The inverse set.
  #
  # @example
  #   ranges = [2..5, 8..10]
  #   Range.invert 1..10, ranges #=> [1..1, 6..7]

  def self.invert(containing_range, ranges)
    inverted = Array.new

    last_end = containing_range.first
    ranges.sort_by(&:first).each_with_index do |range, index|
      inverted << ((last_end + (index == 0 ? 0 : 1))..(range.first - 1)) unless last_end == range.first
      last_end = range.last_included
    end

    inverted << ((last_end + (ranges.empty? ? 0 : 1))..(containing_range.last_included))
    inverted.reject! &:empty?

    return inverted
  end

  # @return [true, false] Whether this is an empty range (contains no values).
  def empty?() first == last_included end

  # @private
  def as_json(*)
    [first, last_included]
  end

  # @private
  def to_json(*)
    as_json.to_json
  end

  # Returns a range that has been advanced forward by a given amount.
  #
  # @param [#+] An amount to advance the range by.
  # @return [Range] The advanced range.

  def +(other)
    (first + other)..(last_included + other)
  end

  # @return The highest value that is in the range.
  def last_included
    exclude_end? ? last - 1 : last
  end

  # @return [true, false] Whether this range partially or fully includes
  #   `other`.
  def intersect?(other)
    min <= other.max && other.min <= max
  end
end

# Adds helpful methods to `String`.

class String
  # @return [Range] A range that encompasses all of this String's characters.
  def range() 0..(length - 1) end
end
