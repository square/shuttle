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

  # Fences out HTML tags and character entities. See {Fencer}.

  module Html
    extend self

    def fence(string)
      fence_tags(string).merge! fence_entities(string)
    end

    def fence_tags(string)
      scanner = UnicodeScanner.new(string)

      tokens = Hash.new { |hsh, k| hsh[k] = [] }
      until scanner.eos?
        match       = scanner.scan_until(/</)
        scanner.pos = scanner.pos - 1 # rewind back to tag opening
        break unless match

        start = scanner.pos
        token = scanner.scan(/<\s*(\/\s*)?\w+(\s+[a-zA-Z0-9\-]+(="?.+?"?)?)*\s*(\/\s*)?>/)
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

    def fence_entities(string)
      scanner = UnicodeScanner.new(string)

      tokens = Hash.new
      until scanner.eos?
        match       = scanner.scan_until(/&/)
        scanner.pos = scanner.pos - 1 # rewind back to ampersand
        break unless match

        start = scanner.pos
        token = scanner.scan(/&(#[0-9]{1,3}|#x[0-9a-fA-F]{1,4}|[0-9a-zA-Z]+);/)
        unless token
          # advance past the & again, so as not to catch it the next time around
          scanner.pos = scanner.pos + 1
          next
        end
        stop = scanner.pos - 1

        tokens[token] ||= Array.new
        tokens[token] << (start..stop)
      end

      return tokens
    end

    # Verifies that the HTML is valid.

    def valid?(string)
      wrapped_str = HTML_TEMPLATE.sub('%{string}', string)
      @validator ||= PageValidations::HTMLValidation.new(nil, %w(-utf8))
      validation = @validator.validation(wrapped_str, '_')
      return validation.valid?
    end

    # @private
    HTML_TEMPLATE = <<-HTML
<!DOCTYPE html>
<html>
  <head>
    <title>test</title>
  </head>
  <body>
    <div>%{string}</div>
  </body>
</html>
    HTML
  end
end
