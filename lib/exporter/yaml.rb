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

require 'psych'

module Exporter

  # Exports the translated strings of a Commit to a YAML file suitable for use
  # with the Ruby i18n gem.

  class Yaml < Base
    def export(io, *locales)
      output = locales.inject({}) do |hsh, locale|
        #TODO for now we assume that the Rails app uses the default Rails i18n
        # fallback logic -- in other words, any locale falls back to any parent
        # under the same locale family (en-US -> en)
        dedupe_from = @commit.project.required_locales.select { |rl| locale.child_of?(rl) }
        dedupe_from.delete locale

        locale_translations_hash = translation_hash(locale, dedupe_from)
        hsh[locale.rfc5646] = locale_translations_hash if locale_translations_hash.present?
        hsh
      end

      io.puts Psych.dump(output, line_width: -1)
      # YAML can add newlines to long strings which messes up multibyte characters
    end

    def self.request_format() :yaml end

    def self.valid?(contents)
      YAML.load(contents).kind_of?(Hash)
    rescue Psych::SyntaxError
      return false
    end
  end
end
