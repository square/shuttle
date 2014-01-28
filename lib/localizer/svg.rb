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

module Localizer

  # Applies localized copy to SVG files.

  class Svg < Base
    def self.localizable?(project, key)
      key.source.end_with?("-#{project.base_rfc5646_locale}.svg")
    end

    def localize(input_file, output_file, locale)
      xml = Nokogiri::XML(input_file.content)

      @translations.each do |translation|
        xml.css(translation.key.original_key).first.inner_html = translation.copy
      end

      output_file.path    = input_file.path.sub(/-#{Regexp.escape @project.base_rfc5646_locale}\.svg$/, "-#{locale.rfc5646}.svg")
      output_file.content = xml.to_xml
    end
  end
end
