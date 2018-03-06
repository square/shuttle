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

  # Fences out Message Format tags using the intl-messageformat syntax.
  # See https://github.com/yahoo/intl-messageformat.
  # Also, see {Fencer}.

  module IntlMessageFormat
    extend self

    UNESCAPED_LEFT_BRACE = /(^.?|[^\\][^\\]){/
    UNESCAPED_RIGHT_BRACE = /(^.?|[^\\][^\\])}/

    def fence(string)
      scanner = UnicodeScanner.new(string)

      tokens  = Hash.new { |hsh, k| hsh[k] = [] }
      until scanner.eos?
        match = scanner.scan_until(UNESCAPED_LEFT_BRACE)
        break unless match

        start = scanner.pos - 1         # less the brace
        token = scanner.scan_until(UNESCAPED_RIGHT_BRACE)
        next unless token

        stop          = scanner.pos - 1 # ranges are inclusive
        tokens['{' + token] << (start..stop)
      end

      return tokens
    end

    # Scan string to ensure that left braces are paired with right braces
    # and that left braces are closed before encountering another left brace.
    def valid?(string)
      scanner = UnicodeScanner.new(string)

      first_left_brace_match = scanner.scan_until(UNESCAPED_LEFT_BRACE)
      return true unless first_left_brace_match

      until scanner.eos?
        # Make sure there's a right brace to match with the left one.
        right_brace_match = scanner.scan_until(UNESCAPED_RIGHT_BRACE)
        return false unless right_brace_match

        right_brace_index = scanner.pos
        scanner.unscan # Reset to last time we saw a left brace.

        # If there are no more left braces, we're good.
        left_brace_match = scanner.scan_until(UNESCAPED_LEFT_BRACE)
        return true unless left_brace_match

        # Make sure the next right brace happens before the next left brace.
        left_brace_index = scanner.pos
        return false if left_brace_index < right_brace_index
      end
    end
  end
end
