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

  # Parses translatable strings from SVG files.

  class Svg < Base
    def self.fencers() %w(Html) end

    protected

    def import_file?
      file.path.end_with?("-#{base_rfc5646_locale}.svg")
    end

    def import_strings
      xml = Nokogiri::XML(file.contents)

      xml.css('text, textpath').each do |element|
        add_string "#{file.path}:#{element.path}", element.inner_html, original_key: element.path
      end
    end
  end
end
