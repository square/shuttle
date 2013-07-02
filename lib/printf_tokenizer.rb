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

# A tokenizer that lexes `printf`-style tokens in a string and yields them along
# with the rest of the string.

module PrintfTokenizer
  extend self

  POSITION            = /\d+\$/                                              # "%2$i"
  FORMAT              = /[\-+ #0]/                                           # "%-i"
  PRECISION_SPECIFIER = /(\d+|\*(\d+\$)?)/                                   # "2" or "*" or "*2$"
  PRECISION           = /#{PRECISION_SPECIFIER}?(\.#{PRECISION_SPECIFIER})?/ # "%*.3f"
  WIDTH               = /([Lhjlqtz]|hh|ll)/                                  # "%ld"
  TYPE                = /[@ACDEFGOSUXacdefgionpsux]/                         # "%d"

  # Yields substrings and tokens from a string. The entire string will be
  # yielded, in pieces, with tokens yielded separately.
  #
  # @param [String] string A string to scan for `printf`-style tokens.
  # @yield [type, value, range] Code to run for each found token or substring.
  # @yieldparam [Symbol] type `:token` if a token was found, or `:substring` if
  #   it's a regular substring.
  # @yieldparam [String] value The portion of the string `type` is referring to.
  # @yieldparam [Range] range The location of the substring in the original
  #   string.

  def tokenize(string)
    scanner = UnicodeScanner.new(string)

    until scanner.eos?
      start_pos = scanner.pos

      match = scanner.scan_until(/(^%|[^%]%)/)
      if match
        yield :substring, match[0..-2], start_pos..(scanner.pos - 1)
      else
        match = string[scanner.pos..-1]
        yield(:substring, match, start_pos..(string.length - 1)) if match.present?
        break
      end

      start_pos = scanner.pos

      if scanner.peek(1) == '%'
        scanner.pos = scanner.pos + 1 # advance past the other %; we'll deal with it below
        yield(:token, '%%', (start_pos - 1)..(scanner.pos - 1))
        next
      end
      scanner.pos = scanner.pos - 1 # rewind back to percent

      start_pos = scanner.pos

      token = scanner.scan(/%#{POSITION}?#{FORMAT}?#{PRECISION}#{WIDTH}?#{TYPE}/)
      unless token
        # advance past the % again, so as not to catch it next time around
        scanner.pos = scanner.pos + 1
        yield(:substring, '%', start_pos..(scanner.pos))
        next
      end

      yield :token, token, start_pos..(scanner.pos - 1)
    end
  end
end
