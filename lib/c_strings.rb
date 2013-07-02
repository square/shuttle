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

# Module that adds functions related to C-style strings.

module CStrings
  protected

  # Unescapes C-style strings.
  #
  # @param [String] str A string with C-style escapes.
  # @return [String] The unescaped string.

  def unescape(str)
    result = ''
    scanner = UnicodeScanner.new(str)

    until scanner.eos?
      match = scanner.scan_until /\\/
      unless match
        result << scanner.scan(/.*/)
        next
      end
      result << match[0..-2]
      if scanner.scan(/\\/)
        result << '\\'
      elsif scanner.scan(/"/)
        result << '"'
      elsif scanner.scan(/n/)
        result << "\n"
      elsif scanner.scan(/r/)
        result << "\r"
      elsif scanner.scan(/t/)
        result << "\t"
      elsif (match = scanner.scan(/[0-9a-f]{4}/))
        result << Integer("0x#{match}").chr('utf-16')
      elsif (match = scanner.scan(/[0-7]{3}/))
        result << Integer("0o#{match}").chr
      elsif (match = scanner.scan(/[0-9a-f]{2}/))
        result << Integer("0x#{match}").chr
      else
        raise "Invalid escape sequence at position #{scanner.pos} in #{str.inspect}"
      end
    end

    return result
  end
end
