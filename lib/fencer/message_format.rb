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

module Fencer

  # Fences out tokens in Java `MessageFormat` strings. See {Fencer}.
  #
  # For more information, see http://docs.oracle.com/javase/1.4.2/docs/api/java/text/MessageFormat.html

  module MessageFormat
    extend self

    def fence(string)
      @parser ||= Parser.new
      result  = @parser.parse(string)
      return {} unless result.kind_of?(Array)

      fences = {}
      result.each do |element|
        element = element[:format_element] or next
        fences[element.to_s] ||= Array.new
        range                = (element.offset)..(element.offset + element.size - 1)
        fences[element.to_s] << range
      end
      return fences
    rescue Parslet::ParseFailed
      return {}
    end

    # @private Parses tokens out of MessageFormat strings.
    class Parser < Parslet::Parser
      rule(:message_format_pattern) { (string | format_element.as(:format_element)).repeat(1) }
      rule(:format_element) do
        (str('{') >> argument_index >> str('}')) |
            (str('{') >> argument_index >> str(',') >> format_type >> str('}')) |
            (str('{') >> argument_index >> str(',') >> format_type >> str(',') >> format_style >> str('}'))
      end
      rule(:format_type) { str('number') | str('date') | str('time') | str('choice') }
      rule(:format_style) do
        str('short') | str('medium') | str('long') | str('full') |
            str('integer') | str('currency') | str('percent') |
            subformat_pattern
      end
      rule(:string) { string_part.repeat(1) }
      rule(:string_part) { str("''") | (str("'") >> quoted_string >> str("'")) | unquoted_string }
      rule(:subformat_pattern) { subformat_pattern_part.repeat(1) }
      rule(:subformat_pattern_part) { (str("'") >> quoted_pattern >> str("'")) | unquoted_pattern }

      # A QuotedString can contain arbitrary characters except single quotes.
      rule(:quoted_string) { match("[^']").repeat(1) }
      # An UnquotedString can contain arbitrary characters except single quotes and left curly brackets.
      rule(:unquoted_string) { match("[^'{]").repeat(1) }
      # A QuotedPattern can contain arbitrary characters except single quotes.
      rule(:quoted_pattern) { match("[^']").repeat(1) }
      # An UnquotedPattern can contain arbitrary characters except single quotes, but curly braces within it must be balanced.
      rule(:unquoted_pattern_str) { match("[^'{}]").repeat(1) }
      rule(:unquoted_pattern_braces) { str('{') >> unquoted_pattern.maybe >> str('}') }
      rule(:unquoted_pattern) { (unquoted_pattern_str | unquoted_pattern_braces).repeat(1) }
      # The ArgumentIndex value is a non-negative integer written using the digits '0' through '9'.
      rule(:argument_index) { match('[0-9]').repeat(1) }

      root :message_format_pattern
    end

    # Verifies using a PEG that the interpolations are valid.

    def valid?(string)
      @parser ||= Parser.new
      @parser.parse(string)
      true
    rescue Parslet::ParseFailed
      false
    end
  end
end
