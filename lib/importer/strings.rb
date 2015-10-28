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

require 'strscan'
require 'ios_common'

module Importer

  # Parses translatable strings from Cocoa/Objective-C .strings files.

  class Strings < Base
    include IosCommon

    def self.fencers() %w(Printf) end

    protected

    def import_file?
      file.path =~ /#{Regexp.escape(base_rfc5646_locale)}\.lproj\/[^\/]+\.strings$/
    end

    def self.encoding() %w(UTF-8 UTF-16BE UTF-16LE) end

    def import_strings
      file.contents.scan(/(?:\/*\*\s*(.+?)\s*\*\/)?\s*"(.+?)"\s*=\s*"(.+?)";/um).each do |(context, key, value)|
        unless value.start_with?(DO_NOT_LOCALIZE_TOKEN)
          add_string "#{file.path}:#{unescape(key)}", unescape(value),
                              context:      context,
                              original_key: unescape(key)
        else
          log_skip key, "Value contains DNL token"
          next
        end
      end
    end

    private

    def unescape(str)
      result = ""
      scanner = UnicodeScanner.new(str)

      until scanner.eos?
        match = scanner.scan_until /\\/
        unless match
          result << scanner.scan(/.*/m)
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
end
