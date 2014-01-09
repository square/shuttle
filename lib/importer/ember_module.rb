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

  class EmberModule < Base
    def self.fencers() %w(Mustache Html) end

    protected

    def import_file?(locale=nil)
      %W(
          #{locale_to_use(locale).rfc5646}.module.js
          #{locale_to_use(locale).rfc5646}.module.coffee
      ).include?(::File.basename(file.path))
    end

    def import_strings(receiver)
      rfc = locale_to_use(receiver.locale).rfc5646

      unless has_translations?
        log_skip nil, "No translations"
        return
      end

      contents          = file.contents
      contents          = CoffeeScript.compile(contents) if ::File.extname(file.path) == '.coffee'
      context           = V8::Context.new
      context['module'] = {'exports' => {}}
      context.eval contents

      context.eval('module.exports')

      hash = context.eval('module.exports').to_hash
      extract_hash(hash) { |key, value| receiver.add_string key, value }
    end

    def has_translations?
      contents = file.contents
      contents.include?('module.exports')
    end
  end
end
