# encoding: utf-8

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

# A library that converts spelling and phraseology between dialects of a
# language using automated dictionaries. These dictionaries are stored in
# `data/spelling`.
#
# This library can automatically find "substitution paths" between locales for
# which dictionaries do not directly exist. For example, you can perform word
# substitution from en-US to en-scotland because en-US can be converted to
# en-GB, which can be converted to en-scotland.
#
# @example
#   american_english = Locale.from_rfc5646('en-US')
#   candian_english = Locale.from_rfc5646('en-CA')
#   result = WordSubstitutor.new(american_english, canadian_english).substitutions("This is the wrong color.")
#   result.string #=> "This is the wrong colour."

class WordSubstitutor
  # Determines whether a WordSubstitutor can be created that converts between
  # the given locales.
  #
  # @param [Locale] from A locale to convert from.
  # @param [Locale] to A locale to convert to.
  # @return [true, false] Whether the necessary dictionaries exist to do the
  #   conversion.

  def self.available?(from, to)
    !graph.route(from, to).nil?
  end

  # @overload initialize(from, to)
  #   Creates a WordSubstitutor that converts from the given locale to the
  #   given locale.
  #   @param [Locale] from A locale to convert from.
  #   @param [Locale] to A locale to convert to.
  #   @raise [NoDictionaryError] If the dictionary(ies) don't exist to allow
  #     conversion between the given locales.

  def initialize(dictionary_or_from_locale, to_locale=nil)
    if to_locale
      @from = dictionary_or_from_locale
      @to   = to_locale
      route = self.class.graph.route(@from, @to)
      raise NoDictionaryError, "Cannot find word substitution dictionary for #{@from.rfc5646} -> #{@to.rfc5646}" unless route
      @dictionaries = route.map.with_index do |_, i|
        "#{route[i].rfc5646},#{route[i+1].try! :rfc5646}.yml"
      end.slice(0..-2).map { |name| YAML.load_file(Rails.root.join('data', 'spelling', name)) }
    else
      @dictionaries = [dictionary_or_from_locale]
    end
  end

  # Returns a {Result} object containing the converted string plus any notes or
  # suggestions for the reviewer.
  #
  # @param [String] string A string to convert.
  # @return [Result] The converted string plus additional notes and suggestions.

  def substitutions(string)
    return chained_substitutions(string) if @dictionaries.size > 1

    result        = Result.new(string.dup)
    auto_rules    = []
    prompt_rules  = []
    stemmed_rules = []
    @dictionaries.first.each do |rule|
      case rule[2]
        when :auto then auto_rules << rule
        when :prompt then prompt_rules << rule
        when :stemmed then stemmed_rules << rule
        else
          raise "Unknown rule type #{rule[2].inspect}"
      end
    end

    apply_auto_substitutions result, auto_rules
    apply_stemmed_substitutions result, stemmed_rules
    apply_suggestions result, prompt_rules

    return result
  end

  private

  def self.graph
    @replacements_graph ||= begin
      graph = Graph.new

      Dir.glob(Rails.root.join('data', 'spelling', '*.yml')).each do |file|
        from, to = File.basename(file, '.yml').split(',').map { |l| Locale.from_rfc5646(l) }
        next unless from && to
        graph << from << to
        graph.connect from, to
      end

      graph
    end
  end

  def self.stemmer
    @stemmer ||= UEAStemmer.new
  end

  # @private cache stemmer.stem_with_rule
  STEMS = {}

  def self.stem_with_rule(word)
    STEMS[word] ||= stemmer.stem_with_rule(word)
  end

  def self.stem(word)
    stem_with_rule(word).word
  end

  def chained_substitutions(string)
    subs   = @dictionaries.map { |dict| WordSubstitutor.new(dict) }
    result = Result.new(string)

    subs.each do |sub|
      this_result        = sub.substitutions(result.string)
      result.suggestions += this_result.suggestions
      result.notes       += this_result.notes
      result.string      = this_result.string # has to come last so ranges are adjusted
    end

    return result
  end

  def apply_auto_substitutions(result, auto_rules)
    modified_ranges = []

    auto_rules.each do |(from_word, to_word, _, note)|
      found_match   = false

      # first attempt an exact match
      result.string = result.string.gsub(/\b#{Regexp.escape from_word}\b/i) do |matched|
        found_match = true
        range       = ($`.length)..(matched.length + $`.length - 1)

        result.notes << Note.new(range, note) if note

        # try to find a matching capitalization; add a suggestion if unable
        new_word = match_capitalization(matched, to_word)
        if new_word
          modified_ranges << range
          new_word
        else
          range = ($`.length)..(matched.length + $`.length - 1)
          result.suggestions << Suggestion.new(range, to_word, "Couldn’t figure out the capitalization for this automatic substitution")
          matched
        end
      end

      next if found_match

      # then attempt a stemming match
      result_words = match_stem(result, from_word) do |words, result_words, index|
        range = if index.min == 0
                  # nothing before
                  range = 0..(words[index].length - 1)
                else
                  range = (words[0, index.min-1].join.length)..(words[0, index.min-1].join.length + words[index].length - 1)
                end

        result.notes << Note.new(range, note) if note

        # find the rule that was used to go from the stem to the inflection we found
        from_with_rule = self.class.stem_with_rule(words[index].join.downcase)
        # apply the suffix that was removed as part of that rule to the new word to match inflections
        new_word       = if from_with_rule.rule
                           self.class.stem(to_word) + words[index].join[(-from_with_rule.rule.suffix_size)..-1]
                         else
                           to_word
                         end

        range = (words[0, index.min].join.length)..(words[0, index.min].join.length + words[index].join.length - 1)

        # try to find matching capitalization; add a suggestion if unable
        result_words[index]   = match_capitalization(words[index].join, new_word) || begin
          result.suggestions << Suggestion.new(range, new_word, "Couldn’t figure out the capitalization for this automatic substitution")
          words[index].join
        end

        modified_ranges << range
      end

      result.string = result_words.join
    end

    result.modified_ranges += modified_ranges
  end

  def apply_suggestions(result, prompt_rules)
    suggested_ranges = []

    prompt_rules.each do |(from_word, to_word, _, note)|
      found_match = false

      # first attempt an exact match
      result.string.matches(/\b#{Regexp.escape from_word}\b/i).each do |match|
        found_match = true

        range = (match.begin(0))..(match.end(0) - 1)
        # we don't want to include suggestions on any part of the string that
        # was modified by another rule or has a suggestion from another rule
        next if result.modified_ranges.any? { |r| range.intersect? r }
        next if suggested_ranges.any? { |r| range.intersect? r }

        suggestion = match_capitalization(match[0], to_word) || to_word
        result.suggestions << Suggestion.new(range, suggestion, note)
        suggested_ranges << range
      end

      next if found_match

      # then attempt a stemming match
      match_stem(result, from_word) do |words, _, index|
        range = (words[0, index.min].join.length)..(words[0, index.min].join.length + words[index].join.length - 1)
        # we don't want to include suggestions on any part of the string that
        # was modified by another rule
        next if result.modified_ranges.any? { |r| range.intersect? r }
        next if suggested_ranges.any? { |r| range.intersect? r }

        # find the rule that was used to go from the stem to the inflection we found
        from_with_rule = self.class.stem_with_rule(words[index].join.downcase)
        # apply the suffix that was removed as part of that rule to the new word to match inflections
        new_word       = if from_with_rule.rule
                           self.class.stem(to_word) + words[index].join[(-from_with_rule.rule.suffix_size)..-1]
                         else
                           to_word
                         end

        suggestion = match_capitalization(words[index].join, new_word) || new_word
        result.suggestions << Suggestion.new(range, suggestion, note)
        suggested_ranges << range
      end
    end
  end

  def apply_stemmed_substitutions(result, stemmed_rules)
    words           = result.string.split(/\b/)
    result_words    = words.dup
    stems           = words.map { |w| self.class.stem_with_rule(w.downcase) }
    modified_ranges = []

    stems.each_with_index do |from_stem_with_rule, index|
      matching_rule = stemmed_rules.detect { |sr| sr.first.downcase == from_stem_with_rule.word }
      next unless matching_rule

      stem_rules = matching_rule[3]
      next unless stem_rules.include?(from_stem_with_rule.rule_num)
      new_word            = stem_rules[from_stem_with_rule.rule_num].
          gsub('%{root}', from_stem_with_rule.word).
          gsub('%{suffix}', words[index][(-from_stem_with_rule.rule.suffix_size)..-1]).
          gsub(/%\{root:(-?\d+)\.\.(-?\d+)\}/) do
        from_stem_with_rule.word[($1.to_i)..($2.to_i)]
      end.
          gsub(/%\{suffix:(-?\d+)\.\.(-?\d+)\}/) do
        words[index][(-from_stem_with_rule.rule.suffix_size)..-1][($1.to_i)..($2.to_i)]
      end

      range = (words[0, index].join.length)..(words[0, index].join.length + words[index].length - 1)

      # try to find a matching capitalization; add a suggestion if unable
      result_words[index] = match_capitalization(words[index], new_word) || begin
        result.suggestions << Suggestion.new(range, new_word, "Couldn’t figure out the capitalization for this stemmed substitution")
        words[index]
      end

      result.string = result_words.join
      modified_ranges << range
    end

    result.modified_ranges += modified_ranges
  end

  def match_capitalization(original_word, new_word)
    if original_word == original_word.downcase
      new_word.downcase
    elsif original_word == original_word.upcase
      new_word.upcase
    elsif original_word == original_word.capitalize
      new_word.capitalize
    else
      nil
    end
  end

  # splits a string into an array of stems and finds the first stem that matches
  # a given word. yields that word and its index range in the array of stems; returns
  # an array of words
  def match_stem(result, from_word)
    words        = result.string.split(/\b/)
    result_words = words.dup
    stems        = words.map { |word| self.class.stem word.downcase }
    from_stem    = from_word.split(/\b/).map { |w| self.class.stem w }
    stems.each_index do |index|
      next unless stems[index, from_stem.size] == from_stem
      yield words, result_words, index..(index+from_stem.size - 1)
    end

    return result_words
  end

  # A result of a word substitution operation. Contains the following fields:
  #
  # |               |                                                                     |
  # |:--------------|:--------------------------------------------------------------------|
  # | `string`      | The converted string.                                               |
  # | `notes`       | An array of {Note} objects with notes for the reviewer.             |
  # | `suggestions` | An array of {Suggestion} objects with suggestions for the reviewer. |

  class Result < Struct.new(:string, :notes, :suggestions, :modified_ranges)
    # @private
    def initialize(*)
      super
      self.notes           ||= []
      self.suggestions     ||= []
      self.modified_ranges ||= []
    end

    # This is currently unused because this is just used for auto-translations.
    # Note that this slows down the word substitutor TREMENDOUSLY.  Computing levenshtein
    # distance that often for every word is _awful_.
    #
    # @private also adjusts all note and suggestion ranges
    # def string=(new_string)
    #   return super if string.nil? || new_string.nil? || string == new_string

    #   # we'll calculate which ranges to shift how much by getting the edit
    #   # distance of the string. in the process of getting the edit distance,
    #   # we'll record the position of additions and deletions.
    #   range_changes = offsets(string, new_string)
    #   range_changes.each do |(from_index, delta)|
    #     notes.each { |note| note.range = shift_range(note.range, from_index, delta) }
    #     suggestions.each { |sugg| sugg.range = shift_range(sugg.range, from_index, delta) }
    #   end

    #   # now update the string
    #   super
    # end

    # @private
    def as_json(*)
      {
          'string'      => string,
          'notes'       => notes,
          'suggestions' => suggestions
      }.as_json
    end

    private

    # finds the amount to offset ran
    # ges within s1 as it changes to s2
    def offsets(s1, s2)
      operations = Levenshtein.new.edits(s1, s2)
      offsets    = []
      counter    = 0
      operations.reverse.each do |operation|
        case operation.move
          when :replace # advance counter forward and do not modify ranges
            counter += 1
          when :insert # shift all ranges after the counter ahead 1
            offsets << [counter, +1]
            counter += 1
          when :delete # shift all ranges after the counter back 1
            offsets << [counter, -1]
        end
      end

      return offsets
    end

    def shift_range(range, from_index, delta)
      (from_index <= range.min ? range.min + delta : range.min)..(from_index <= range.max ? range.max + delta : range.max)
    end
  end

  # A change performed to transform one Array or String to another. Returned
  # by Levenshtein#edits. Contains the following fields:
  #
  # |        |                                                 |
  # |:-------|:------------------------------------------------|
  # | `cost` | The cost associated with this change.           |
  # | `move` | The type of move performed. eg insert, replace. |
  # | `one`  | The string or character transformed from.       |
  # | `two`  | The string or character transformed to.         |
  class Move < Struct.new(:cost, :move, :one, :two)
  end

  # Class that computes the Levenshtein distance
  class Levenshtein
    EDITS_MEMO = Hash.new { |h, k| h[k] = Hash.new }

    # Finds the series of edits necessary to transform `s1` into `s2`. Uses the
    # recursive Levenshtein algorithm.
    #
    # @param [Array, String] s1 Object to compare. Must be of same type as other
    #   parameter.
    # @param [Array, String] s2 Object to compare. Must be of same type as other
    #   parameter.
    # @return [Array<Move>] The full history of edits required to transform `s1`
    #   to `s2`.
    def edits(s1, s2)
      if (memo = EDITS_MEMO[s1][s2])
        return memo
      end
      if String === s1 && String === s2
        s1 = s1.split("")
        s2 = s2.split("")
      end

      # BASE CASES

      # if they're both empty, create an "initial" node
      return memoize_edit(s1, s2, [Move.new(0, :start, "", "")]) if s1.empty? && s2.empty?
      # if they're equal, only zero-cost substitutions are required
      return memoize_edit(s1, s2, s1.map { |l| Move.new(0, :replace, l, l) }.reverse) if s1 == s2
      # if s1 is empty, the operations to get to s2 is to just insert every character from s2 into s1
      return memoize_edit(s1, s2, s2.length.times.map { |i| Move.new(s2.length - i, :insert, "", s2[s2.length - i - 1]) }) if s1.empty?
      # if s2 is empty, the operations to get to s2 is to just delete every character in s1
      return memoize_edit(s1, s2, s1.length.times.map { |i| Move.new(s1.length - i, :delete, s1[s1.length - i - 1], "") }) if s2.empty?

      # RECURSIVE CASE
      # apply the levenshtein algorithm to the last character

      # calculate the cost of substitution: 0 if the letters are equal; 1 otherwise
      substitution_cost = s1[-1] == s2[-1] ? 0 : 1

      # build 3 potential moves
      insert            = Move.new(1, :insert, "", s2[-1])
      delete            = Move.new(1, :delete, s1[-1], "")
      replace           = Move.new(substitution_cost, :replace, s1[-1], s2[-1])
      # for each move, find the chain of moves that precedes it
      insert_moves      = edits(s1, s2[0..-2]).dup
      delete_moves      = edits(s1[0..-2], s2).dup
      replace_moves     = edits(s1[0..-2], s2[0..-2]).dup
      # add to each move the cumulative cost so far
      insert.cost       += insert_moves.first.cost
      delete.cost       += delete_moves.first.cost
      replace.cost      += replace_moves.first.cost
      # add the move to the chain
      insert_moves.unshift insert
      delete_moves.unshift delete
      replace_moves.unshift replace

      # return the lowest-cost move
      return memoize_edit(s1, s2, [insert_moves, delete_moves, replace_moves].min_by { |chain| chain.first.cost })
    end

    private

    def memoize_edit(s1, s2, value)
      EDITS_MEMO[s1][s2] = value if value
      value
    end
  end

  # A suggestion resulting from `:prompt`-type rule. The substitution is not
  # made automatically. Contains the following fields:
  #
  # |               |                                                                  |
  # |:--------------|:-----------------------------------------------------------------|
  # | `range`       | The Range to which the suggestion applies, in the result string. |
  # | `replacement` | The suggested replacement for that range.                        |
  # | `note`        | Additional information for the reviewer.                         |

  class Suggestion < Struct.new(:range, :replacement, :note)
  end

  # A note about a substitution that was made automatically.
  #
  # |         |                                                            |
  # |:--------|:-----------------------------------------------------------|
  # | `range` | The Range to which the note applies, in the result string. |
  # | `note`  | Information for the reviewer.                              |

  class Note < Struct.new(:range, :note)
  end

  # Raised when the dictionary(ies) do not exist to make a substitution between
  # two locales.
  class NoDictionaryError < StandardError
  end

  # @private
  class Graph
    def initialize
      @locales = Hash.new
    end

    def <<(locale)
      @locales[locale.rfc5646] ||= Node.new(locale)
      self
    end

    def connect(from, to)
      raise ArgumentError, "Locale #{from.rfc5646} not in substitution graph" unless @locales[from.rfc5646]
      raise ArgumentError, "Locale #{to.rfc5646} not in substitution graph" unless @locales[to.rfc5646]
      @locales[from.rfc5646].nodes << @locales[to.rfc5646]
    end

    def route(from, to)
      return nil unless @locales[from.rfc5646] && @locales[to.rfc5646]
      path = @locales[from.rfc5646].route(to)
      path ? path.map(&:locale) : nil
    end
  end

  # @private
  class Node < Struct.new(:locale, :nodes)
    def initialize(*)
      super
      self.nodes ||= []
    end

    def route(to)
      # do a recursive breadth-first search for the route
      return [self] if locale == to
      nodes.each do |node|
        path = node.route(to)
        return [self, *path] if path
      end
      return nil
    end
  end
end
