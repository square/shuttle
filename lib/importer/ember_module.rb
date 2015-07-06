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
require 'importer/ember'

module Importer

  # Parses localizable strings from JavaScript/CoffeeScript files with Ember
  # I18n string hashes.

  class EmberModule < Ember
    protected

    def import_file?
      %W(
          #{base_rfc5646_locale}.module.js
          #{base_rfc5646_locale}.module.coffee
      ).include?(::File.basename(file.path))
    end

    def has_translations_for_locale?(_)
      file.contents.include?('module.exports')
    end

    private

    def extract_hash_from_file(contents, rfc)
      context           = V8::Context.new
      context['module'] = {'exports' => {}}
      context.eval contents

      context.eval('module.exports')

      context.eval('module.exports').to_hash
    end
  end
end
