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

module Exporter

  # Exports the translated strings of a Commit to a .strings file for use with
  # Cocoa/Objective-C.

  class Strings < Base
    C_STRING_ESCAPES = Hash.new { |h,k| k }
    C_STRING_ESCAPES['\\'] = '\\\\'
    C_STRING_ESCAPES["\t"] = '\t'
    C_STRING_ESCAPES["\r"] = '\r'
    C_STRING_ESCAPES["\n"] = '\n'
    C_STRING_ESCAPES['"' ] = '\"'

    # Exports the translated strings of the commit to a .strings file in the
    # locale provided.
    #
    # @raise [NoLocaleProvidedError] If a single locale is not provided.

    def export(io, *locales)
      raise NoLocaleProvidedError, ".strings files can only be for a single locale" unless locales.size == 1
      locale = locales.first

      # write the BOM
      io.putc 0xFF
      io.putc 0xFE

      translations = Translation.in_commit(@commit).where(rfc5646_locale: locale.rfc5646).
          sort_by { |t| t.key.key }
      translations.each { |translation| export_translation io, translation }
    end

    # Appends a single Translation to an export stream.
    #
    # @param [IO] io The stream to write to.
    # @param [Translation] translation The translation to export.

    def export_translation(io, translation)
      part = ''
      part << "/* #{translation.key.context} */\n" if translation.key.context.present?
      part << %("#{escape translation.key.original_key}" = "#{escape translation.copy}";\n)
      part << "\n"

      io.write part.encode('UTF-16LE').force_encoding('BINARY')
    end

    def self.file_extension() 'strings' end
    def self.character_encoding() 'UTF-16LE' end
    def self.request_format() :strings end
    def self.multilingual?() false end

    private

    def escape(str)
      result = ""
      scanner = UnicodeScanner.new(str)

      until scanner.eos?
        match = scanner.scan_until /[\\\t\r\n"]/
        unless match
          result << scanner.scan(/.*/m)
          next
        end
        result << match[0..-2]
        case match[-1, 1]
          when '\\'
            result << '\\\\'
          when "\t"
            result << '\t'
          when "\r"
            result << '\r'
          when "\n"
            result << '\n'
          when '"'
            result << '\"'
          else
            raise "Invalid escape sequence at position #{scanner.pos} in #{str.inspect}"
        end
      end

      return result
    end

    # @private
    STRING_WITH_ESCAPES_NO_NL = /"([^\n"]|\\")*"/m
    # @private
    SPACE_NO_NL = /[ \t]*/m
    # @private
    PAIR = /#{STRING_WITH_ESCAPES_NO_NL}#{SPACE_NO_NL}=#{SPACE_NO_NL}#{STRING_WITH_ESCAPES_NO_NL}#{SPACE_NO_NL};/m
    # @private
    PAIR_PRECEDED_BY_NEWLINE = /#{SPACE_NO_NL}\n+#{SPACE_NO_NL}#{PAIR}/m

    def self.valid?(contents)
      contents =~ /\A\s*#{PAIR}(#{PAIR_PRECEDED_BY_NEWLINE})*\s*\z/m
    end
  end
end
