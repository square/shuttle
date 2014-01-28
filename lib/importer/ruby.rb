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

module Importer

  # Parses translatable strings from Ruby i18n `.rb` files.

  class Ruby < Base
    def self.fencers() %w(RubyI18n) end

    protected

    def import_file?(locale=nil)
      ::File.dirname(file.path).starts_with?('/config/locales') &&
          ::File.extname(file.path) == '.rb'
    end

    def import_strings(receiver)
      output = nil
      Thread.start do
        $SAFE  = 4
        output = eval(file.contents)
      end.join

      locale = locale_to_use(receiver.locale).rfc5646

      unless output.kind_of?(Hash)
        log_skip nil, "Does not evaluate to a Hash"
        return
      end
      unless output.stringify_keys![locale]
        log_skip nil, "No translations for #{locale}"
        return
      end

      extract_hash(output[locale]) do |key, string|
        receiver.add_string(key, string)
      end
    end
  end
end
