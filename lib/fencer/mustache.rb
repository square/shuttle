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

  # Fences out Mustache tags. See {Fencer}.

  module Mustache
    extend self

    def fence(string)
      scanner = UnicodeScanner.new(string)

      tokens  = Hash.new { |hsh, k| hsh[k] = [] }
      until scanner.eos?
        match = scanner.scan_until(/\{\{/)
        break unless match

        start = scanner.pos - 2         # less the two braces
        token = scanner.scan_until(/\}?\}\}/)
        next unless token

        stop          = scanner.pos - 1 # ranges are inclusive
        tokens['{{' + token] << (start..stop)
      end

      return tokens
    end

    def valid?(string)
      @parser ||= ::Mustache::Parser.new
      @parser.compile string
      true
    rescue ::Mustache::Parser::SyntaxError
      false
    end
  end
end
