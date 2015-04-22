# encoding: utf-8

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

  class Android < Base
    include AndroidQualifiers

    # XML files that could contain localizable resources.
    FILENAMES = %w(country_names.xml strings.xml arrays.xml plurals.xml titles.xml)

    def self.localizable?(project, key)
      _, qualifiers = AndroidQualifiers::parse_qualifiers(::File.basename(::File.dirname(key.source)))
      file_locale   = Locale.new(qualifiers['language'] || project.base_locale.iso639,
                                 nil,
                                 nil,
                                 qualifiers['region'].try!(:[], 1, 2) || project.base_locale.region)

      file_locale == project.base_locale && FILENAMES.include?(::File.basename(key.source))
    end

    def localize(input_file, output_file, locale)
      xml = Nokogiri::XML(input_file.content)

      # xml.css is a costly method, calling it for each key separately is very slow.
      # So, we create a temporary cache in the form of a hash.
      xml_strings_hash = xml.css("string").reduce({}) do |hsh, elt|
        key = elt.attr(:name)
        raise "Multiple tags with key #{key} found" if hsh.key?(key)
        hsh.tap { |hsh| hsh[key] = elt }
      end

      xml_string_arrays_hash = xml.css("string-array").reduce({}) do |hsh, elt|
        key = elt.attr(:name)
        raise "Multiple string-array tags with key #{key} found" if hsh.key?(key)
        hsh.tap { |hsh| hsh[key] = elt }
      end

      xml_plurals_hash = xml.css("plurals").reduce({}) do |hsh, elt|
        key = elt.attr(:name)
        raise "Multiple tags with key #{key} found" if hsh.key?(key)
        hsh.tap { |hsh| hsh[key] = elt }
      end

      @translations.each do |translation|
        key = translation.key.key.split(':').last
        case key
          when /^(\w+)\[(\d+)\]$/
            tag = xml_string_arrays_hash[$1]
            raise "No string-array tag with key #{$1} found" unless tag

            subtag = tag.css('item')[$2.to_i]
            raise "No string-array child tag with key #{$1}[#{$2}] found" unless subtag

            subtag.inner_html = escape(translation.copy)
          when /^(\w+)\[(\w+)\]$/
            tag = xml_plurals_hash[$1]
            raise "No tag with key #{$1} found" unless tag

            subtags = tag.css("item[quantity=#{$2}]")
            raise "Multiple plurals child tags with key #{$1} found" if subtags.size > 1
            raise "No plurals child tag with key #{$1}[#{$2}] found" if subtags.empty?

            subtags.first.inner_html = escape(translation.copy)
          else
            tag = xml_strings_hash[key]
            raise "No tag with key #{key} found" unless tag
            tag.inner_html = escape(translation.copy)
        end
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

    def escape(copy)
      copy.gsub(/(\\|'|@|\n|\r\n)/, "\\" => "\\\\", "'" => "\\'", "@" => "\\@", "\n" => "\\n", "\r\n" => "\\n")
    end
  end
end
