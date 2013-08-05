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

# This library provides a single method {::diff} that formats two strings to
# highlight the differences between the two in a compact fashion.
#
# @example
#   one = "A nice simple string"
#   two = "A nice complex string"
#   result = TranslationDiff.diff(one, two)
#   result = ["...nice simple  string", "...nice complex string"]

class TranslationDiff

  # Determines the differences between two strings and gives a nice
  # compact representation of the differences with context. Ignores excess
  # white-spaces.
  #
  # @return [Array<String>] The original parameters formatted to highlight
  #   the differences.
  def self.diff(str1, str2, joiner="...")
    # Base cases
    return ["", ""] if str1 == "" && str2 == ""

    words1 = str1.gsub(/\s+/m, " ").split(" ")
    words2 = str2.gsub(/\s+/m, " ").split(" ")

    diff = WordSubstitutor::Levenshtein.new.edits(words1, words2).reverse
    diff = diff.select { |m| m.one.present? || m.two.present? } # Remove empty differences
    chunks = diff.map { |m| Chunk.new(m.one, m.two) }
    first_is_change = chunks.first.one != chunks.first.two
    last_is_change = chunks.last.one != chunks.last.two

    # Make all chunk strings equal length to partner
    chunks = chunks.map do |chunk|
      len = chunk.one.length > chunk.two.length ? chunk.one.length : chunk.two.length
      chunk.one = chunk.one.center(len)
      chunk.two = chunk.two.center(len)
      chunk
    end

    # Add context
    changes = chunks.map { |c| c.one != c.two }
    ranges = context_ranges(changes, 1)
    consolidated = ranges.map do |range|
      chunks.slice(range).reduce(:append)
    end

    # No changes!
    if consolidated.size == 0
      return ["", ""]
    end

    # Formatting to add leading and trailing ellipses
    unless first_is_change
      consolidated.unshift(Chunk.new("", ""))
    end
    unless last_is_change
      consolidated.push(Chunk.new("", ""))
    end
    [consolidated.map { |m| m.one }.join(joiner), consolidated.map { |m| m.two }.join(joiner)]
  end

  Chunk = Struct.new(:one, :two) do
    def append(other)
      self.one += " #{other.one}"
      self.two += " #{other.two}"
      self
    end
  end

  # @private
  # Finds context-sensitive runs of truthy values.
  #
  # @param [Array<true, false>] Array of whether that index has a difference.
  # @param [Integer] The amount of context on either side to include.
  # @returns [Array<Range>] An Array of Ranges from the first parameter that have
  #   context-sensitive runs of truths.
  def self.context_ranges(changes, context)
    # Convert to searchable string
    changes_string = changes.each_with_index.map { |c, i| c ? "[#{i}]" : "-" }.join("")

    # Chop off leading and trailing falses
    changes_string = changes_string.gsub(/^-+/, "").gsub(/-+$/, "")

    # Compress false runs
    min_false_run = "-" * (2 * context + 1)
    run_strings = changes_string.gsub(Regexp.new(min_false_run + "+"), min_false_run).split(min_false_run)

    # Compute actual runs with inner context
    runs = run_strings.map do |s|
      first_start = 1 # Given chop off leading falses, will always lead with bracket
      first_len = s.index("]") - first_start
      last_start = s.index(/\[\d+\]$/) + 1 # Last bracket set
      last_len = s.length - last_start - 1

      first = s[first_start, first_len].to_i
      last = s[last_start, last_len].to_i

      [first, last]
    end

    # Adjust for outer context
    runs.map do |first, last|
      first = first >= context ? first - context : 0
      last = (last < changes.length - context) ? (last + context) : (changes.length - 1)
      first..last
    end
  end
end
