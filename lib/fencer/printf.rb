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

  # Fences out `printf()` interpolation tokens, as used in Objective-C .strings
  # files (such as "%s"). See {Fencer}.

  module Printf
    extend self

    POSITION            = /\d+\$/                                              # "%2$i"
    FORMAT              = /[\-+ #0]/                                           # "%-i"
    PRECISION_SPECIFIER = /(\d+|\*(\d+\$)?)/                                   # "2" or "*" or "*2$"
    PRECISION           = /#{PRECISION_SPECIFIER}?(\.#{PRECISION_SPECIFIER})?/ # "%*.3f"
    WIDTH               = /([Lhjlqtz]|hh|ll)/                                  # "%ld"
    TYPE                = /[@ACDEFGOSUXacdefgionpsux]/                         # "%d"

    def fence(string)
      scanner = UnicodeScanner.new(string)

      tokens  = Hash.new { |hsh, k| hsh[k] = [] }
      counter = 0
      until scanner.eos?
        match = scanner.scan_until(/(^%|[^%]%)/)
        break unless match

        if scanner.peek(1) == '%'
          scanner.pos = scanner.pos + 1 # advance past the other %; we'll deal with it below
          next
        end
        scanner.pos = scanner.pos - 1 # rewind back to percent

        start = scanner.pos
        token = scanner.scan(/%#{POSITION}?#{FORMAT}?#{PRECISION}#{WIDTH}?#{TYPE}/)
        unless token
          # advance past the % again, so as not to catch it next time around
          scanner.pos = scanner.pos + 1
          next
        end
        stop = scanner.pos - 1

        token.match /^%(\d+\$)?(.+)$/
        if (position = $1)
          tokens['%' + position + $2] = [start..stop]
          # keep the counter at the highest visited position, so that when we
          # tokenize the %%'s below, we don't use any taken position values
          intpos                = position[0..-2].to_i
          counter = intpos if intpos > counter
        else
          counter                         += 1
          tokens['%' + counter.to_s + '$' + $2] << (start..stop)
        end
      end

      return tokens
    end

    # No particular validation checking.
    def valid?(_) true end
  end
end
