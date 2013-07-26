# encoding: utf-8

# Copyright 2013 Square Inc.
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

  class Android < Base
    include AndroidQualifiers

    # XML files that could contain localizable resources.
    FILENAMES = %w(strings.xml arrays.xml plurals.xml titles.xml)

    def self.localizable?(project, path)
      _, qualifiers = AndroidQualifiers::parse_qualifiers(::File.basename(::File.dirname(path)))
      file_locale   = Locale.new(qualifiers['language'] || project.base_locale.iso639,
                                 nil,
                                 nil,
                                 qualifiers['region'].try!(:[], 1, 2) || project.base_locale.region)

      file_locale == project.base_locale && FILENAMES.include?(::File.basename(path))
    end

    def localize(input_file, output_file, locale)
      xml = Nokogiri::XML(input_file.content)

      @translations.each do |translation|
        xpath                             = translation.key.key.sub(/^#{Regexp.escape translation.key.source}:/, '')
        xml.xpath(xpath).first.inner_html = process_copy(translation.copy)
      end

      # build a path, replacing the parent directory with the correct qualifiers
      path                   = input_file.path.sub(/^\//, '').split('/')
      base, qualifiers       = parse_qualifiers(path[-2])
      qualifiers['language'] = locale.iso639
      qualifiers['region'] = 'r' + locale.region if locale.region
      path[-2]         = serialize_qualifiers(base, qualifiers)
      output_file.path = path.join('/')

      output_file.content = xml.to_xml
    end

    private

    def process_copy(copy)
      # fix bug with smart quotes in Roboto font
      copy.gsub('’', "'")
    end
  end
end
