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

    def import_file?
      %W(
          #{base_rfc5646_locale}.js
          #{base_rfc5646_locale}.coffee
      ).include?(::File.basename(file.path))
    end

    def import_strings
      unless has_translations_for_locale?(base_rfc5646_locale)
        log_skip nil, "No translations for #{base_rfc5646_locale}"
        return
      end

      contents = file.contents
      contents = CoffeeScript.compile(contents) if ::File.extname(file.path) == '.coffee'
      hash = extract_hash_from_file(contents, base_rfc5646_locale)

      extract_hash(hash) { |key, value| add_string key, value }
    # TODO: We need to move this over to NodeJS instead.  RubyRacer has an issue where ExecJS will randomly fail with a ProgramError.
    # RuntimeError catches for syntax issues though which is most likely what we're interested in.
    # https://github.com/sstephenson/execjs/blob/master/lib/execjs/ruby_racer_runtime.rb
    rescue ExecJS::RuntimeError, V8::Error => err
      log_skip nil, "Invalid Ember file: #{err}"
      handle_import_error(err)
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
