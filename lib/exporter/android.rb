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

# encoding: utf-8

require 'android_qualifiers'
require 'exporter/multifile'

module Exporter

  # Exports the translated strings of a Commit to a .tar file (containing
  # XML files) for use with Android. This tarball should be extracted to the
  # project's root directory.

  class Android < Base
    include AndroidQualifiers
    include Multifile

    def export_files(receiver, *locales)
      # We have to organize translations by the eventual file that the
      # translation will be stored into. Then, for each file, we can process
      # the translations accordingly.

      files = Hash.new { |hsh, k| hsh[k] = Array.new }

      Translation.in_commit(@commit).includes(:key).
          where(rfc5646_locale: locales.map(&:rfc5646), translated: true).find_each do |translation|
        unless translation.key.source
          Rails.logger.warn "[Exporter::Android] Skipping #{translation.key.inspect} - nil source"
          next
        end
        next unless translation.key.source.end_with?('.xml')
        unless translation.key.key.include?(':')
          Rails.logger.warn "[Exporter::Android] Skipping #{translation.key.key.inspect} - invalid key"
          next
        end

        # build a path, replacing the parent directory with the correct qualifiers
        path                   = translation.key.source.sub(/^\//, '').split('/')
        base, qualifiers       = parse_qualifiers(translation.key.key.split(':')[1])
        qualifiers['language'] = translation.locale.iso639
        qualifiers['region'] = 'r' + translation.locale.region if translation.locale.region
        path[-2] = serialize_qualifiers(base, qualifiers)
        files[path.join('/')] << translation
      end

      files.each do |path, translations|

        # in order to reconstitute the XML correctly, we'll need to organize
        # translations by their parent tag types (string, string-array, or plurals),
        # ensuring that string-array translations are stored in order.

        string_translations = Array.new                                # unordered translations
        array_translations  = Hash.new { |hsh, k| hsh[k] = Array.new } # maps keys to an ordered array of translations
        plural_translations = Hash.new { |hsh, k| hsh[k] = Hash.new }  # maps keys to an hash of translations by quantity type

        translations.sort_by(&:key).each do |translation|
          key_parts = translation.key.key.split(':')
          type      = key_parts.first

          case type
            when 'string'
              string_translations << translation
            when 'array'
              array_translations[translation.key.original_key][key_parts.last.to_i] = translation
            when 'plurals'
              plural_translations[translation.key.original_key][key_parts.last] = translation
          end
        end

        # now that everything's organized and ready to go, we can create an
        # XML document and append it to the tar writer

        doc = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
          xml.resources do
            string_translations.each do |translation|
              xml.string fix_copy(translation.copy), xml_attributes(translation).merge('name' => translation.key.original_key)
            end

            array_translations.each do |key, elements|
              raise "string-array missing one or more elements" if elements.select(&:nil?).size > 0
              xml.send('string-array', name: key) do
                elements.each do |translation|
                  xml.item fix_copy(translation.copy), xml_attributes(translation)
                end
              end
            end

            plural_translations.each do |key, forms|
              xml.plurals(name: key) do
                forms.to_a.sort_by(&:first).each do |(quantity, translation)|
                  xml.item fix_copy(translation.copy), xml_attributes(translation).merge('quantity' => quantity)
                end
              end
            end
          end
        end

        receiver.add_file path, escape_unicode(doc.to_xml)
      end
    end

    def self.request_format() :android end

    private

    def xml_attributes(translation)
      translation.key.other_data.present? ? Hash[translation.key.other_data['attributes']] : {}
    end

    # some android fonts render curly single quotes incorrectly; dumbify those
    # quotes
    def fix_copy(str)
      str.gsub(/‘/, "'").gsub(/’/, "'")
    end

    def escape_unicode(str)
      output = String.new
      str.each_char do |char|
        if char == "'"
          output << "\\'"
        elsif char == '\\'
          output << '\\\\'
        else
          output << char
        end
      end

      output.gsub("\\\\n", "\\n")
    end
  end
end
