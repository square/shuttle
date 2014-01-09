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

  # Fences out ERb escapes. See {Fencer}.

  module Erb
    extend self

    def fence(string)
      scanner = UnicodeScanner.new(string)

      tokens = Hash.new { |hsh, k| hsh[k] = [] }
      until scanner.eos?
        match       = scanner.scan_until(/</)
        scanner.pos = scanner.pos - 1 # rewind back to tag opening
        break unless match

        start = scanner.pos
        token = scanner.scan(/<%(.+?)%>/)
        unless token
          # advance past the < again, so as not to catch it the next time around
          scanner.pos = scanner.pos + 1
          next
        end
        stop = scanner.pos - 1

        tokens[token] << (start..stop)
      end

      return tokens
    end

    # Verifies that `<%`s and `%>`s are balanced.

    def valid?(string)
      string.scan(/<%/).size == string.scan(/%>/).size
    end
  end
end
