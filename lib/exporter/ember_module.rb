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

module Exporter

  # Exports the translated strings of a Commit to a JavaScript file formatted
  # for use with the Ember I18n library.
  #
  # @raise [NoLocaleProvidedError] If a single locale is not provided.

class EmberModule < Base
    def export(io, *locales)
      raise NoLocaleProvidedError, "Dependency-injected Ember.js files can only be for a single locale" unless locales.size == 1
      locale = locales.first

      dedupe_from = @commit.project.required_locales.select { |rl| locale.child_of?(rl) }
      dedupe_from.delete locale
      dedupe_from << @commit.project.base_locale

      io.puts %(module.exports = #{JSON.pretty_generate translation_hash(locale, dedupe_from)};)
    end

    def self.request_format() :jsm end

    def self.valid?(contents)
      return false if contents.blank?

      context  = V8::Context.new
      context['module'] = {}
      context.eval contents
      return true
    rescue V8::Error
      return false
    end
  end
end
