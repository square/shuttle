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

module Importer

  # Parses localizable strings from JavaScript/CoffeeScript files with Ember
  # I18n string hashes.

  class Ember < Base
    def self.fencers() %w(Mustache Html) end

    protected

    def import_file?(locale=nil)
      %W(
          #{locale_to_use(locale).rfc5646}.js
          #{locale_to_use(locale).rfc5646}.coffee
      ).include?(::File.basename(file.path))
    end

    def import_strings(receiver)
      rfc = locale_to_use(receiver.locale).rfc5646

      unless has_translations_for_locale?(rfc)
        log_skip nil, "No translations for #{rfc}"
        return
      end

      contents = file.contents
      contents = CoffeeScript.compile(contents) if ::File.extname(file.path) == '.coffee'
      hash = extract_hash_from_file(contents, rfc)

      extract_hash(hash) { |key, value| receiver.add_string key, value }
    rescue Exception => err
      log_skip nil, "Invalid CoffeeScript file: #{err}"
      @commit.add_import_error_in_redis(file.path, err) if @commit
    end

    def has_translations_for_locale?(locale)
      contents = file.contents
      contents.include?(%(Ember.I18n.locales.translations["#{locale}"])) ||
        contents.include?(%(Ember.I18n.locales.translations.#{locale}))
    end

    private

    def extract_hash_from_file(contents, rfc)
      context  = V8::Context.new
      context['Ember'] = {'I18n' => {'locales' => {'translations' => {}}}}
      context.eval contents

      context.eval("Ember.I18n.locales.translations")
      context.eval("Ember.I18n.locales.translations").to_hash

      context.eval("Ember.I18n.locales.translations")[rfc].to_hash.except('CLDRDefaultLanguage')
    end
  end
end
