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

# Container module for all fencers. All fencers respond to a `.fence` method
# that returns a Hash. The keys of this Hash are string tokens, and the values
# are Arrays of Ranges indicating where in the string each token appears.
#
# For example, given the Mustache string
#
# ```` mustache
# Hello {{name}}! Welcome to {{place}}! I can call you {{name}}, right?
# ````
#
# the fencer would return
#
# ```` ruby
# {
#   '{{name}}'  => [6..13, 53..60],
#   '{{place}}' => [27..35]
# }
# ````

module Fencer

  # Runs a string through multiple fencers and collates the results. Fenced
  # ranges marked by earlier fencers will not be run through later fencers.
  #
  # @param [Array<String, Module>] fencers An array of fencers (or the names of
  #   fencers without "Fencer::") to use, in priority order.
  # @param [String] copy The string to fence.

  def self.multifence(fencers, copy)
    fencers = fencers.map { |fencer| fencer.kind_of?(Module) ? fencer : Fencer.const_get(fencer) }
    combined = Hash.new { |hsh, k| hsh[k] = [] }
    all_fenced_ranges = []
    fencers.each do |fencer|
      ranges_to_fence = Range.invert(copy.range, all_fenced_ranges)
      ranges_to_fence.each do |range|
        fences = fencer.fence(copy[range])
        fences.each do |token, fenced_ranges|
          fenced_ranges.map! { |fenced_range| fenced_range + range.first }
          combined[token].concat fenced_ranges
          all_fenced_ranges.concat fenced_ranges
        end
      end
    end

    return combined
  end

  def self.fencers
    constants
  end
end
