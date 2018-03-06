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

  # Parses localizable strings from JSON/YAML files for use with the ember-intl
  # addon.

  class EmberIntl < Base
    def self.fencers() %w(IntlMessageFormat Html) end

    protected

    def import_file?
      in_correct_folder? && has_correct_name? && (file_is_json? || file_is_localizable_yaml?)
    end

    def import_strings
      hash = file_is_yaml? ? get_yaml_strings(file.contents) : get_json_strings(file.contents)
      extract_hash(hash) { |key, string| add_string key, string } if hash.present?
    end

    def get_json_strings(file_contents)
      begin
        JSON.parse(file_contents)
      rescue JSON::ParserError => err
        log_skip nil, "Invalid JSON file: #{err}"
        handle_import_error(err)
        return
      end
    end

    def get_yaml_strings(file_contents)
      begin
        YAML.load(file_contents)
      rescue Psych::SyntaxError => err
        log_skip nil, "Invalid YAML file: #{err}"
        handle_import_error(err)
        return
      end
    end

    private

    def file_is_json?
      ::File.extname(file.path) == '.json'
    end

    def file_is_yaml?
      %w(.yaml .yml).include?(::File.extname(file.path))
    end

    def file_is_localizable_yaml?
      file_is_yaml? && ::File.basename(file.path, '.*').downcase != 'owners'
    end

    def in_correct_folder?
      ::File.dirname(file.path).include?('translations')
    end

    def has_correct_name?
      ::File.basename(file.path, '.*').downcase == base_rfc5646_locale.downcase
    end
  end
end
