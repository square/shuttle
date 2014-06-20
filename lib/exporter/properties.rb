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

  # Exports the translated strings of a Commit to a Java .properties file.
  #
  # @raise [NoLocaleProvidedError] If a single locale is not provided.

  class Properties < Base
    def export(io, *locales)
      raise NoLocaleProvidedError, ".properties files can only be for a single locale" unless locales.size == 1
      locale = locales.first

      translations = Translation.in_commit(@commit).
          where(rfc5646_locale: locale.rfc5646).
          sort_by { |t| t.key.key }
      translations.each { |translation| export_translation io, translation }
    end

    # Appends a single Translation to an export stream.
    #
    # @param [IO] io The stream to write to.
    # @param [Translation] translation The translation to export.

    def export_translation(io, translation)
      io.puts %(#{translation.key.original_key}=#{translation.copy})
    end

    def self.request_format() :properties end
    def self.multilingual?() false end

    # @private
    STRING_ESCAPED_EQ_NO_NL = /(?:[^\n=]|\\=)+/m
    # @private
    SPACE_NO_NL = /[ \t]*/m
    # @private
    PAIR = /#{STRING_ESCAPED_EQ_NO_NL}#{SPACE_NO_NL}=#{SPACE_NO_NL}#{STRING_ESCAPED_EQ_NO_NL}/m
    # @private
    PAIR_PRECEDED_BY_NEWLINE = /#{SPACE_NO_NL}\n+#{SPACE_NO_NL}#{PAIR}/m

    def self.valid?(contents)
      contents =~ /\A\s*#{PAIR}(#{PAIR_PRECEDED_BY_NEWLINE})*\s*\z/m
    end
  end
end
