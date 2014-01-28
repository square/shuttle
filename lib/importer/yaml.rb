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

  # Parses translatable strings from Ruby i18n YAML files.

  class Yaml < Base
    def self.fencers() %w(RubyI18n) end

    protected

    def import_file?(locale=nil)
      ::File.dirname(file.path).starts_with?('/config/locales') &&
          %w(.yaml .yml).include?(::File.extname(file.path))
    end

    def import_strings(receiver)
      begin
        yml = YAML.load(file.contents)
      rescue Exception => err
        log_skip nil, "Invalid YAML file: #{err}"
        return
      end

      locale = locale_to_use(receiver.locale).rfc5646
      return unless yml[locale]
      extract_hash(yml[locale]) do |key, string|
        receiver.add_string(key, string)
      end
    end
  end
end
