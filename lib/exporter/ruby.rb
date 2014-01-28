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

require 'pp'

module Exporter

  # Exports the translated strings of a Commit to a Ruby source file suitable
  # for use with the Ruby i18n gem.

  class Ruby < Base
    def export(io, *locales)
      output = locales.inject({}) do |hsh, locale|
        #TODO for now we assume that the Rails app uses the default Rails i18n
        # fallback logic -- in other words, any locale falls back to any parent
        # under the same locale family (en-US -> en)
        dedupe_from = @commit.project.required_locales.select { |rl| locale.child_of?(rl) }
        dedupe_from.delete locale

        hsh[locale.rfc5646] = translation_hash(locale, dedupe_from)
        hsh
      end

      PP.pp output, io
    end

    def self.request_format() :rb end

    def self.valid?(contents)
      value = Thread.start do
        $SAFE  = 4
        eval contents
      end.value
      value.kind_of?(Hash)
    rescue Object
      return false
    end
  end
end
