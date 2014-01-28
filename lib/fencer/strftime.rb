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

  # Fences out `strftime()` sentinels (such as "%H" for hour). See {Fencer}.

  module Strftime
    extend self

    FLAGS      = /([\-_0^#:]|::)/
    WIDTH      = /\d+/
    MODIFIER   = /[EO]/
    CONVERSION = /[ABCDFGHILMNPRSTUVWXYZabcdeghjklmnprstuvwxyz]/

    def fence(string)
      scanner = UnicodeScanner.new(string)

      tokens  = Hash.new { |hsh, k| hsh[k] = [] }
      counter = 0
      until scanner.eos?
        match = scanner.scan_until(/%/)
        break unless match

        if scanner.peek(1) == '%'
          scanner.pos = scanner.pos + 1 # advance past the other %; we'll deal with it below
          next
        end
        scanner.pos = scanner.pos - 1 # rewind back to percent

        start = scanner.pos
        token = scanner.scan(/%#{FLAGS}?#{WIDTH}?#{MODIFIER}?#{CONVERSION}/)
        unless token
          # advance past the % again, so as not to catch it next time around
          scanner.pos = scanner.pos + 1
          next
        end
        stop = scanner.pos - 1

        counter                                   += 1
        tokens['%' + counter.to_s + '$' + token[1..-1]] << (start..stop)
      end

      scanner.reset
      until scanner.eos?
        match = scanner.scan_until(/%%/)
        break unless match
        counter                     += 1
        tokens['%' + counter.to_s + '$%'] = [(scanner.pos - 2)..(scanner.pos - 1)]
      end

      return tokens
    end

    # No particular validation checking.
    def valid?(_) true end
  end
end
