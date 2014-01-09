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

class Ember < Base
    def export(io, *locales)
      locales.each do |locale|
        #TODO ember does not usually handle fallbacks at all; we're assuming the
        # presence of Square-specific extensions ember extensions here
        dedupe_from = @commit.project.required_locales.select { |rl| locale.child_of?(rl) }
        dedupe_from.delete locale
        dedupe_from << @commit.project.base_locale

        io.puts %(#{translations_key_path(locale)} = #{JSON.pretty_generate translation_hash(locale, dedupe_from)};)
      end
    end

    def translations_key_path(locale)
      locale = locale.rfc5646
      "Ember.I18n.locales.translations#{locale =~ /^\w+$/ ? ".#{locale}" : %(["#{locale}"])}"
    end

    def self.request_format() :js end

    def self.valid?(contents)
      return false if contents.blank?

      context  = V8::Context.new
      context['Ember'] = {'I18n' => {'locales' => {'translations' => {}}}}
      context.eval contents
      return true
    rescue V8::Error
      return false
    end
  end
end
