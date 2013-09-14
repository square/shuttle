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

require 'android_qualifiers'

module Importer

  # Parses translatable strings from Android XML resource files. Because Android
  # strings can have multiple "qualifiers" attached (e.g., this string applies
  # only to high-DPI screens in the French language), these qualifiers are
  # parsed out from the directory name and serialized into the key. The
  # {Exporter::Android exporter} de-serializes them and recreates the correct
  # directory structure.

  class Android < Base
    include AndroidQualifiers

    # XML files that could contain localizable resources.
    FILENAMES = %w(strings.xml arrays.xml plurals.xml titles.xml)

    def self.fencers() %w(Android) end

    protected

    def import_file?(locale=nil)
      _, qualifiers = parse_qualifiers(::File.basename(::File.dirname(file.path)))
      file_locale   = Locale.new(qualifiers['language'] || @blob.project.base_locale.iso639,
                                 nil,
                                 nil,
                                 qualifiers['region'].try!(:[], 1, 2) || @blob.project.base_locale.region)

      file_locale == locale_to_use(locale) && FILENAMES.include?(::File.basename(file.path))
    end

    def import_strings(receiver)
      xml = Nokogiri::XML(file.contents)

      xml.xpath('/resources/string').each do |tag|
        if tag['translatable'] == 'false'
          log_skip tag.path, 'marked as translatable=false'
          next
        end

        context = find_comment(tag).try!(:content)
        receiver.add_string "#{file.path}:#{tag.path}",
                            unescape(tag.content),
                            context:      clean_comment(context),
                            original_key: tag['name']
      end

      xml.xpath('/resources/string-array').each do |tag|
        if tag.attributes['translatable'] == 'false'
          log_skip tag.path, 'marked as translatable=false'
          next
        end

        global_context = find_comment(tag).try!(:content)
        tag.xpath('item').each do |item_tag|
          context = find_comment(item_tag).try!(:content)
          receiver.add_string "#{file.path}:#{item_tag.path}",
                              unescape(item_tag.content),
                              context:      clean_comment(context || global_context),
                              original_key: tag['name']
        end
      end

      xml.xpath('/resources/plurals').each do |tag|
        if tag['translatable'] == 'false'
          log_skip tag.path, 'marked as translatable=false'
          next
        end

        global_context = find_comment(tag).try!(:content)
        tag.xpath('item').each do |subtag|
          context = find_comment(subtag).try!(:content)
          receiver.add_string "#{file.path}:#{subtag.path}",
                              unescape(subtag.content),
                              context:      clean_comment(context || global_context),
                              original_key: tag['name']
        end
      end
    end

    def self.default_interpolator
      return "android"
    end 

    def attributes_from_tag(tag, *except)
      attrs = tag.keys.zip(tag.values)
      attrs.delete_if { |(k, _)| except.include? k }
      attrs
    end

    private

    def unescape(string)
      if string =~ /^"(.+?)"$/
        $1
      else
        string.gsub("\\'", "'")
      end.gsub(/\\u([0-9a-f]{4})/) { $1.to_i(16).chr(Encoding::UTF_8) }
    end

    def find_comment(tag)
      tag = tag.previous
      tag = tag.previous while tag.try!(:text?)
      tag.try!(:comment?) ? tag : nil
    end

    def clean_comment(comment)
      return nil if comment.blank?
      comment.split("\n").map do |line|
        line.gsub(/^\s*-/, '').strip
      end.reject(&:blank?).join(' ')
    end
  end
end
