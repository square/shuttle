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

# This library provides a single method {::diff} that formats two strings to
# highlight the differences between the two in a compact fashion.
#
# @example
#   one = "A nice simple string"
#   two = "A nice complex string"
#   result = TranslationDiff.diff(one, two)
#   result = ["...nice simple  string", "...nice complex string"]

class TranslationDiff

  # Creates an object that will perform diffs on two Strings
  def initialize(str1, str2)
    @str1 = str1 && str1.dup
    @str2 = str2 && str2.dup
  end

  # @private
  # Centered version of all edits required to substitute
  def chunks
    return @chunks if @chunks
    words1 = (@str1 || "").gsub(/\s+/m, " ").split(" ")
    words2 = (@str2 || "").gsub(/\s+/m, " ").split(" ")
    diff = WordSubstitutor::Levenshtein.new.edits(words1, words2).reverse
    diff = diff.select { |m| m.one.present? || m.two.present? }
    chunks = diff.map { |m| Chunk.new(m.one, m.two) }
    @chunks = chunks.map do |chunk|
      len = chunk.one.length > chunk.two.length ? chunk.one.length : chunk.two.length
      chunk.one = chunk.one.center(len)
      chunk.two = chunk.two.center(len)
      chunk
    end
  end
  private :chunks

  # Determines the differences between the two strings being compared and gives
  # a nice compact representation of the differences with context. Ignores
  # excess white-spaces.
  #
  # @return [Array<String>] The two strings being compared, formatted to
  #   highlight the differences.
  def diff(joiner="...")
    # Base cases
    return [@str1, @str2] unless @str1.present? || @str2.present?
    return @diff if @diff

    # Add context
    changes = chunks.map { |c| c.one != c.two }
    ranges = context_ranges(changes, 1)
    stripped_chunks = chunks.map { |c| Chunk.new(c.one.strip, c.two.strip) }
    consolidated = ranges.map do |range|
      stripped_chunks.slice(range).reduce(:append)
    end
    if consolidated.size == 0
      return ["", ""]
    end

    # Formatting to add leading and trailing ellipses
    if chunks.first.one == chunks.first.two
      consolidated.unshift(Chunk.new("", ""))
    end
    if chunks.last.one == chunks.last.two
      consolidated.push(Chunk.new("", ""))
    end
    @diff ||= [consolidated.map { |m| m.one }.join(joiner), consolidated.map { |m| m.two }.join(joiner)]
  end

  # @return [Array<String>] The two strings being compared, padded to
  #   visually align words that are matched according to minimal Levenshtein
  #   distance
  def aligned
    @aligned ||= [chunks.map { |m| m.one }.join(" "), chunks.map { |m| m.two }.join(" ")]
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
  # @param [Array<true, false>] changes Array of whether that index has a
  #   difference.
  # @param [Integer] context The amount of context on either side to include.
  # @return [Array<Range>] An Array of Ranges from the first parameter that have
  #   context-sensitive runs of truths.
  def context_ranges(changes, context)
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
